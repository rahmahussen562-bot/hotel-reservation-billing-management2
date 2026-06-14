-- ============================================================
-- Hotel Reservation & Billing Management System
-- 10 Analytical Views & Queries
-- ============================================================


-- ============================================================
-- Q1: Guest Master View
-- ============================================================
-- View: combines guest profile + stay history + total spend
-- LifetimeSpend = sum of all actual payments made by the guest
-- TotalStays    = only fully checked_out reservations

-- Query: Top 20 guests by LifetimeSpend
SELECT TOP 20
    GuestID,
    FullName,
    City,
    TotalStays,
    LifetimeSpend
FROM vw_GuestMaster
ORDER BY LifetimeSpend DESC;
GO

IF OBJECT_ID('vw_GuestMaster', 'V') IS NOT NULL
    DROP VIEW vw_GuestMaster;
GO

CREATE VIEW vw_GuestMaster AS
SELECT 
    G.GuestID, 
    G.FullName, 
    G.NationalID_Passport, 
    G.Phone, 
    G.Email, 
    G.City,
    COUNT(CASE 
        WHEN R.reservation_status = 'checked_out' 
        THEN 1 
    END) AS TotalStays,

    ISNULL(SUM(I.PaidAmount), 0) AS LifetimeSpend

FROM Guests G
LEFT JOIN Reservations R ON G.GuestID = R.GuestID
LEFT JOIN Invoices     I ON R.ReservationID = I.ReservationID
GROUP BY 
    G.GuestID, G.FullName, G.NationalID_Passport, 
    G.Phone, G.Email, G.City;
GO


SELECT TOP 20 
    GuestID, FullName, NationalID_Passport, 
    Phone, Email, City, TotalStays, LifetimeSpend
FROM vw_GuestMaster
ORDER BY LifetimeSpend DESC;
GO

-- ============================================================
-- Q2: Room Availability View (by date range)
-- ============================================================
-- Shows every room with its type and nightly rate.
-- AvailabilityStatus in the view is the physical status from Rooms.
-- To check availability for a date range we filter in the query below.

IF OBJECT_ID('vw_RoomAvailability', 'V') IS NOT NULL
    DROP VIEW vw_RoomAvailability;
GO

CREATE VIEW vw_RoomAvailability AS
SELECT 
    R.RoomID, 
    R.RoomNumber, 
    RT.TypeName       AS RoomType, 
    RT.NightlyPrice   AS NightlyRate,
    R.BuildingID,
    R.AvailabilityStatus AS InternalStatus
FROM Rooms     R
JOIN RoomTypes RT ON R.RoomTypeID = RT.RoomTypeID;
GO

DECLARE @InDate  DATE = '2026-03-10';
DECLARE @OutDate DATE = '2026-03-15';

SELECT 
    RoomID, RoomNumber, RoomType, NightlyRate,
    'Available' AS AvailabilityStatus
FROM vw_RoomAvailability
WHERE InternalStatus <> 'Maintenance'
  AND RoomID NOT IN (
    SELECT RoomID 
    FROM Reservations 
    WHERE reservation_status IN ('confirmed', 'checked_in')
      AND check_in_date  < @OutDate
      AND check_out_date > @InDate
  )
ORDER BY NightlyRate;
GO

CREATE VIEW vw_RoomAvailability AS
SELECT
    ro.RoomID,
    ro.RoomNumber,
    rt.TypeName          AS RoomType,
    rt.NightlyPrice      AS NightlyRate,
    ro.AvailabilityStatus,
    ro.BuildingID,

    -- Attach any active/future reservation dates so we can filter later
    r.ReservationID,
    r.check_in_date,
    r.check_out_date,
    r.reservation_status

FROM Rooms ro
JOIN RoomTypes   rt ON ro.RoomTypeID = rt.RoomTypeID
LEFT JOIN Reservations r
    ON  ro.RoomID = r.RoomID
    AND r.reservation_status NOT IN ('cancelled', 'no_show')
GO



-- ============================================================
-- Q3: Daily Occupancy Rate
-- ============================================================
-- Generates one row per calendar date in the range.
-- OccupiedRooms = rooms that have an active (checked_in / confirmed)
-- reservation covering that specific date.

DECLARE @RangeStart DATE = '2026-01-01';
DECLARE @RangeEnd   DATE = '2026-03-17';

-- Build a calendar CTE for the date range
WITH Calendar AS (
    SELECT @RangeStart AS CalDate
    UNION ALL
    SELECT DATEADD(day, 1, CalDate)
    FROM   Calendar
    WHERE  CalDate < @RangeEnd
),
-- Total active rooms (not under maintenance)
RoomInventory AS (
    SELECT COUNT(*) AS TotalRooms
    FROM   Rooms
    WHERE  AvailabilityStatus <> 'Maintenance'
      AND  IsActive = 1
),
-- Count rooms occupied on each date
DailyOccupied AS (
    SELECT
        c.CalDate,
        COUNT(DISTINCT r.RoomID) AS OccupiedRooms
    FROM Calendar c
    JOIN Reservations r
        ON  c.CalDate >= r.check_in_date
        AND c.CalDate <  r.check_out_date        -- check-out day is free
        AND r.reservation_status IN ('confirmed','checked_in','checked_out')
    GROUP BY c.CalDate
)
SELECT
    d.CalDate                                        AS [Date],
    ri.TotalRooms,
    ISNULL(d.OccupiedRooms, 0)                       AS OccupiedRooms,
    CAST(
        ISNULL(d.OccupiedRooms, 0) * 100.0
        / NULLIF(ri.TotalRooms, 0)
    AS DECIMAL(5,2))                                 AS [OccupancyRate%]
FROM Calendar c
CROSS JOIN RoomInventory ri
LEFT JOIN  DailyOccupied d ON c.CalDate = d.CalDate
ORDER BY c.CalDate
OPTION (MAXRECURSION 1000);
GO


-- ============================================================
-- Q4: Reservation Details View
-- ============================================================

CREATE VIEW vw_ReservationDetails AS
SELECT
    r.ReservationID,
    g.FullName                                       AS GuestName,
    ro.RoomNumber,
    rt.TypeName                                      AS RoomType,
    r.check_in_date                                  AS CheckInDate,
    r.check_out_date                                 AS CheckOutDate,
    r.nights                                         AS Nights,

    -- Human-readable status label
    CASE r.reservation_status
        WHEN 'confirmed'    THEN 'Booked'
        WHEN 'checked_in'   THEN 'Checked-in'
        WHEN 'checked_out'  THEN 'Checked-out'
        WHEN 'cancelled'    THEN 'Cancelled'
        WHEN 'no_show'      THEN 'No Show'
        ELSE r.reservation_status
    END                                              AS ReservationStatus,

    -- Room charge based on actual nights and rate locked at booking
    r.nights * r.NightlyRateAtBooking                AS TotalRoomCharge,
    r.booking_source                                 AS BookingSource,
    r.NightlyRateAtBooking

FROM Reservations  r
JOIN Guests    g  ON r.GuestID    = g.GuestID
JOIN Rooms     ro ON r.RoomID     = ro.RoomID
JOIN RoomTypes rt ON ro.RoomTypeID = rt.RoomTypeID;
GO

-- Sample query: all current checked-in reservations
SELECT *
FROM vw_ReservationDetails
WHERE ReservationStatus = 'Checked-in'
ORDER BY CheckInDate;
GO


-- ============================================================
-- Q5: Cancellation Analysis
-- ============================================================

-- Monthly cancellation performance
SELECT
    FORMAT(r.booking_date, 'yyyy-MM')            AS YearMonth,
    COUNT(*)                                     AS TotalReservations,
    SUM(CASE WHEN r.reservation_status = 'cancelled' THEN 1 ELSE 0 END)
                                                 AS CancelledReservations,
    CAST(
        SUM(CASE WHEN r.reservation_status = 'cancelled' THEN 1.0 ELSE 0 END)
        * 100.0 / NULLIF(COUNT(*), 0)
    AS DECIMAL(5,2))                             AS [CancellationRate%]
FROM Reservations r
GROUP BY FORMAT(r.booking_date, 'yyyy-MM')
ORDER BY YearMonth;
GO

-- Top 5 cancellation reasons
SELECT TOP 5
    ISNULL(CancellationReason, 'No reason provided') AS CancellationReason,
    COUNT(*)                                          AS CancellationCount
FROM Reservations
WHERE reservation_status = 'cancelled'
GROUP BY CancellationReason
ORDER BY CancellationCount DESC;
GO


-- ============================================================
-- Q6: Services Revenue View
-- ============================================================

CREATE VIEW vw_ServiceRevenue AS
SELECT
    s.ServiceName,
    FORMAT(su.UsageDate, 'yyyy-MM')   AS YearMonth,
    COUNT(su.UsageID)                 AS TotalUsageCount,
    SUM(su.TotalCharge)               AS TotalServiceRevenue
FROM ServiceUsages su
JOIN Services s ON su.ServiceID = s.ServiceID
GROUP BY
    s.ServiceName,
    FORMAT(su.UsageDate, 'yyyy-MM');
GO

-- Query: Top 5 services by revenue in the last 3 months
SELECT TOP 5
    ServiceName,
    SUM(TotalUsageCount)    AS UsageCount,
    SUM(TotalServiceRevenue) AS Revenue
FROM vw_ServiceRevenue
WHERE YearMonth >= FORMAT(DATEADD(MONTH, -3, GETDATE()), 'yyyy-MM')
GROUP BY ServiceName
ORDER BY Revenue DESC;
GO


-- ============================================================
-- Q7: Invoice Aging & Outstanding Balances View
-- ============================================================

CREATE VIEW vw_InvoiceAging AS
SELECT
    i.InvoiceID,
    g.FullName                                            AS GuestName,
    i.InvoiceDate,
    i.NetTotalAmount                                      AS TotalAmount,
    i.PaidAmount,
    (i.NetTotalAmount - i.PaidAmount)                     AS OutstandingAmount,

    -- Age in days from invoice date to today
    DATEDIFF(day, i.InvoiceDate, CAST(GETDATE() AS DATE)) AS AgeDays,

    -- Aging bucket
    CASE
        WHEN DATEDIFF(day, i.InvoiceDate, CAST(GETDATE() AS DATE)) BETWEEN 0  AND 7  THEN '0-7 days'
        WHEN DATEDIFF(day, i.InvoiceDate, CAST(GETDATE() AS DATE)) BETWEEN 8  AND 30 THEN '8-30 days'
        WHEN DATEDIFF(day, i.InvoiceDate, CAST(GETDATE() AS DATE)) BETWEEN 31 AND 60 THEN '31-60 days'
        ELSE '60+ days'
    END                                                   AS AgingBucket,

    i.InvoiceStatus

FROM Invoices i
JOIN Reservations r ON i.ReservationID  = r.ReservationID
JOIN Guests       g ON r.GuestID        = g.GuestID
WHERE (i.NetTotalAmount - i.PaidAmount) > 0   -- only invoices with outstanding balance
  AND i.InvoiceStatus <> 'refunded';
GO

-- Query: all invoices in the 60+ days bucket
SELECT
    InvoiceID,
    GuestName,
    InvoiceDate,
    TotalAmount,
    PaidAmount,
    OutstandingAmount,
    AgeDays,
    InvoiceStatus
FROM vw_InvoiceAging
WHERE AgingBucket = '60+ days'
ORDER BY OutstandingAmount DESC;
GO


-- ============================================================
-- Q8: Payment Method Breakdown (Monthly)
-- ============================================================

SELECT
    FORMAT(p.PaymentDate, 'yyyy-MM')              AS YearMonth,

    SUM(CASE WHEN p.PaymentStatus = 'Completed'
             THEN p.AmountPaid ELSE 0 END)         AS TotalPaid,

    SUM(CASE WHEN p.PaymentMethod = 'Cash'
              AND p.PaymentStatus = 'Completed'
             THEN p.AmountPaid ELSE 0 END)         AS PaidByCash,

    SUM(CASE WHEN p.PaymentMethod = 'Card'
              AND p.PaymentStatus = 'Completed'
             THEN p.AmountPaid ELSE 0 END)         AS PaidByCard,

    SUM(CASE WHEN p.PaymentMethod = 'Online'
              AND p.PaymentStatus = 'Completed'
             THEN p.AmountPaid ELSE 0 END)         AS PaidOnline,

    SUM(CASE WHEN p.PaymentMethod = 'Wallet'
              AND p.PaymentStatus = 'Completed'
             THEN p.AmountPaid ELSE 0 END)         AS PaidByWallet,

    COUNT(CASE WHEN p.PaymentStatus = 'Failed'
               THEN 1 END)                         AS FailedTransactions,

    COUNT(CASE WHEN p.PaymentStatus = 'Pending'
               THEN 1 END)                         AS PendingTransactions

FROM Payments p
GROUP BY FORMAT(p.PaymentDate, 'yyyy-MM')
ORDER BY YearMonth;
GO


-- ============================================================
-- Q9: Housekeeping & Room Turnover Report
-- ============================================================

-- View: housekeeping performance per room
CREATE VIEW vw_HousekeepingPerformance AS
SELECT
    h.RoomID,
    ro.RoomNumber,
    rt.TypeName                                        AS RoomType,
    ro.BuildingID,

    -- Logs in the last 30 days only
    COUNT(CASE
        WHEN h.CleaningDate >= CAST(DATEADD(day,-30,GETDATE()) AS DATE)
        THEN h.LogID
    END)                                               AS CleaningCount_Last30Days,

    -- Average cleaning duration in minutes (all time)
    AVG(DATEDIFF(minute, h.StartTime, h.EndTime))      AS AvgCleaningMinutes,

    -- Count of sessions that started after 14:00 (defined cutoff)
    COUNT(CASE
        WHEN h.StartTime > '14:00:00'
         AND h.CleaningDate >= CAST(DATEADD(day,-30,GETDATE()) AS DATE)
        THEN h.LogID
    END)                                               AS LateCleaningSessions

FROM HousekeepingLogs h
JOIN Rooms     ro ON h.RoomID     = ro.RoomID
JOIN RoomTypes rt ON ro.RoomTypeID = rt.RoomTypeID
GROUP BY
    h.RoomID,
    ro.RoomNumber,
    rt.TypeName,
    ro.BuildingID;
GO

-- Query: rooms with the most late cleaning sessions
SELECT
    RoomID,
    RoomNumber,
    RoomType,
    BuildingID,
    CleaningCount_Last30Days,
    AvgCleaningMinutes,
    LateCleaningSessions
FROM vw_HousekeepingPerformance
ORDER BY LateCleaningSessions DESC, CleaningCount_Last30Days DESC;
GO


-- ============================================================
-- Q10: Staff Performance View (Last 30 Days)
-- ============================================================

-- Query: Top 10 staff by TotalRevenueProcessed (last 30 days)
SELECT TOP 10
    StaffName,
    Role,
    ReservationsHandled,
    CheckInsProcessed,
    CheckOutsProcessed,
    TotalPaymentsProcessed,
    TotalRevenueProcessed
FROM vw_StaffPerformance
ORDER BY TotalRevenueProcessed DESC;
GO
IF OBJECT_ID('vw_StaffPerformance', 'V') IS NOT NULL
    DROP VIEW vw_StaffPerformance;
GO

CREATE VIEW vw_StaffPerformance AS
SELECT 
    e.EmployeeID,
    e.EmpName                       AS StaffName,
    e.JobRole                       AS Role,

    -- Reservations this employee created (as main booking employee)
    COUNT(DISTINCT 
        CASE WHEN r.EmployeeID = e.EmployeeID 
             THEN r.ReservationID 
        END)                        AS ReservationsHandled,

    COUNT(DISTINCT 
        CASE WHEN r.CheckedInByEmployeeID = e.EmployeeID 
             THEN r.ReservationID 
        END)                        AS CheckInsProcessed,

    COUNT(DISTINCT 
        CASE WHEN r.CheckedOutByEmployeeID = e.EmployeeID 
             THEN r.ReservationID 
        END)                        AS CheckOutsProcessed,

    COUNT(DISTINCT p.PaymentID)     AS TotalPaymentsProcessed,
    ISNULL(SUM(
        CASE WHEN p.PaymentStatus = 'Completed' 
             THEN p.AmountPaid ELSE 0 
        END), 0)                    AS TotalRevenueProcessed

FROM Employee e
LEFT JOIN Reservations r 
    ON  e.EmployeeID IN (r.EmployeeID, r.CheckedInByEmployeeID, r.CheckedOutByEmployeeID)
    AND r.booking_date >= DATEADD(DAY, -30, GETDATE())

LEFT JOIN Invoices  i ON r.ReservationID = i.ReservationID
LEFT JOIN Payments  p ON i.InvoiceID     = p.InvoiceID
    AND p.PaymentDate >= DATEADD(DAY, -30, GETDATE())
GROUP BY 
    e.EmployeeID,
    e.EmpName,
    e.JobRole;
GO

-- Query: Top 10 staff by TotalRevenueProcessed
SELECT TOP 10
    StaffName,
    Role,
    ReservationsHandled,
    CheckInsProcessed,
    CheckOutsProcessed,
    TotalPaymentsProcessed,
    TotalRevenueProcessed
FROM vw_StaffPerformance
ORDER BY TotalRevenueProcessed DESC;
GO
