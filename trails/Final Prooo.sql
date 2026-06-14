CREATE TABLE Employees (
    EmployeeID INT IDENTITY(1,1),
    EmpName VARCHAR(100) NOT NULL,
    JobRole VARCHAR(50) NOT NULL, 
    CreatedAt DATETIME DEFAULT GETDATE(),
    UpdatedAt DATETIME DEFAULT GETDATE(),

    CONSTRAINT PK_Employees PRIMARY KEY (EmployeeID)
);

CREATE TABLE RoomTypes (
    RoomTypeID VARCHAR(50) NOT NULL,
    TypeName VARCHAR(50) NOT NULL, 
    NightlyPrice DECIMAL(10, 2) NOT NULL,
    CreatedAt DATETIME DEFAULT GETDATE(),
    UpdatedAt DATETIME DEFAULT GETDATE(),

    CONSTRAINT PK_RoomTypes PRIMARY KEY (RoomTypeID),
    CONSTRAINT CHK_RoomTypes_Price CHECK (NightlyPrice > 0)
);

CREATE TABLE Guests (
    GuestID VARCHAR(50) NOT NULL,
    FullName VARCHAR(150) NOT NULL,
    NationalID_Passport VARCHAR(50) UNIQUE NOT NULL,
    Phone VARCHAR(20),
    Email VARCHAR(100),
    City VARCHAR(50),
    CreatedAt DATETIME DEFAULT GETDATE(),
    UpdatedAt DATETIME DEFAULT GETDATE(),

    CONSTRAINT PK_Guests PRIMARY KEY (GuestID)
);

CREATE TABLE Services (
    ServiceID VARCHAR(50) NOT NULL,
    ServiceName VARCHAR(100) NOT NULL, 
    Price DECIMAL(10, 2) NOT NULL,
    CreatedAt DATETIME DEFAULT GETDATE(),
    UpdatedAt DATETIME DEFAULT GETDATE(),

    CONSTRAINT PK_Services PRIMARY KEY (ServiceID),
    CONSTRAINT CHK_Services_Price CHECK (Price >= 0)
);

CREATE TABLE Rooms (
    RoomID VARCHAR(50) NOT NULL,
    RoomNumber VARCHAR(10) NOT NULL UNIQUE,
    RoomTypeID VARCHAR(50) NOT NULL,
    AvailabilityStatus VARCHAR(20) DEFAULT 'Available',
    CreatedAt DATETIME DEFAULT GETDATE(),
    UpdatedAt DATETIME DEFAULT GETDATE(),

    CONSTRAINT PK_Rooms PRIMARY KEY (RoomID),
    CONSTRAINT FK_Rooms_RoomTypes FOREIGN KEY (RoomTypeID) REFERENCES RoomTypes(RoomTypeID),
    CONSTRAINT CHK_Room_Status 
		CHECK (AvailabilityStatus IN ('Available','Occupied','Maintenance'))
);

CREATE TABLE HousekeepingLogs (
    LogID VARCHAR(50) NOT NULL,
    RoomID VARCHAR(50) NOT NULL,
    CleaningDate DATE NOT NULL,
    StartTime TIME,
    EndTime TIME,
    CreatedAt DATETIME DEFAULT GETDATE(),
    UpdatedAt DATETIME DEFAULT GETDATE(),

    CONSTRAINT PK_HousekeepingLogs PRIMARY KEY (LogID),
    CONSTRAINT FK_Housekeeping_Rooms FOREIGN KEY (RoomID) REFERENCES Rooms(RoomID),
    CONSTRAINT CHK_Cleaning_Time
		CHECK (EndTime > StartTime)
);

CREATE TABLE Reservations (
    ReservationID VARCHAR(50) NOT NULL,
    GuestID VARCHAR(50) NOT NULL,
    RoomID VARCHAR(50) NOT NULL,
    EmployeeID INT NOT NULL, 
    CheckInDate DATE NOT NULL,
    CheckOutDate DATE NOT NULL,
    BookedNightlyPrice DECIMAL(10, 2) NOT NULL,
    ReservationStatus VARCHAR(20) NOT NULL DEFAULT 'Booked', 
    CancellationReason VARCHAR(255) NULL,
    CreatedAt DATETIME DEFAULT GETDATE(),
    UpdatedAt DATETIME DEFAULT GETDATE(),

    CONSTRAINT PK_Reservations PRIMARY KEY (ReservationID),
    CONSTRAINT FK_Reservations_Guests FOREIGN KEY (GuestID) REFERENCES Guests(GuestID),
    CONSTRAINT FK_Reservations_Rooms FOREIGN KEY (RoomID) REFERENCES Rooms(RoomID),
    CONSTRAINT FK_Reservations_Employees FOREIGN KEY (EmployeeID) REFERENCES Employees(EmployeeID),
    CONSTRAINT CHK_Reservation_Status
		CHECK (ReservationStatus IN ('Booked','CheckedIn','CheckedOut','Cancelled')),
    CONSTRAINT CHK_Reservation_Dates
		CHECK (CheckOutDate > CheckInDate)
);

CREATE TABLE ServiceUsages (
    UsageID VARCHAR(50) NOT NULL,
    ReservationID VARCHAR(50) NOT NULL,
    ServiceID VARCHAR(50) NOT NULL,
    UsageDate DATE NOT NULL,
    Quantity INT DEFAULT 1,
    TotalCharge DECIMAL(10, 2) NOT NULL,
    CreatedAt DATETIME DEFAULT GETDATE(),
    UpdatedAt DATETIME DEFAULT GETDATE(),

    CONSTRAINT PK_ServiceUsages PRIMARY KEY (UsageID),
    CONSTRAINT FK_ServiceUsages_Reservations FOREIGN KEY (ReservationID) REFERENCES Reservations(ReservationID),
    CONSTRAINT FK_ServiceUsages_Services FOREIGN KEY (ServiceID) REFERENCES Services(ServiceID),
    CONSTRAINT CHK_Service_Quantity
		CHECK (Quantity > 0),
    CONSTRAINT CHK_Service_Total
		CHECK (TotalCharge >= 0)
);

CREATE TABLE Invoices (
    InvoiceID VARCHAR(50) NOT NULL,
    ReservationID VARCHAR(50) NOT NULL,
    InvoiceDate DATE NOT NULL,
    TotalRoomCharge DECIMAL(10, 2) NOT NULL, 
    TotalServicesCharge DECIMAL(10, 2) DEFAULT 0.00, 
    DiscountAmount DECIMAL(10, 2) DEFAULT 0.00, 
    NetTotalAmount DECIMAL(10, 2) NOT NULL, 
    PaidAmount DECIMAL(10, 2) DEFAULT 0.00,
    CreatedAt DATETIME DEFAULT GETDATE(),
    UpdatedAt DATETIME DEFAULT GETDATE(),

    CONSTRAINT PK_Invoices PRIMARY KEY (InvoiceID),
    CONSTRAINT FK_Invoices_Reservations FOREIGN KEY (ReservationID) REFERENCES Reservations(ReservationID),
    CONSTRAINT CHK_Invoice_Amounts 
		CHECK (
			TotalRoomCharge >= 0 AND
			TotalServicesCharge >= 0 AND
			DiscountAmount >= 0 AND
			NetTotalAmount >= 0 AND
			PaidAmount >= 0
    )
);

CREATE TABLE Payments (
    PaymentID VARCHAR(50) NOT NULL,
    InvoiceID VARCHAR(50) NOT NULL,
    EmployeeID INT NOT NULL,
    PaymentDate DATE NOT NULL,
    AmountPaid DECIMAL(10, 2) NOT NULL,
    PaymentMethod VARCHAR(50) NOT NULL, 
    PaymentStatus VARCHAR(20) DEFAULT 'Completed', 
    CreatedAt DATETIME DEFAULT GETDATE(),
    UpdatedAt DATETIME DEFAULT GETDATE(),

    CONSTRAINT PK_Payments PRIMARY KEY (PaymentID),
    CONSTRAINT FK_Payments_Invoices FOREIGN KEY (InvoiceID) REFERENCES Invoices(InvoiceID),
    CONSTRAINT FK_Payments_Employees FOREIGN KEY (EmployeeID) REFERENCES Employees(EmployeeID),
    CONSTRAINT CHK_Payment_Status 
		CHECK (PaymentStatus IN ('Completed','Pending','Failed')),
    CONSTRAINT CHK_Payment_Amount 
		CHECK (AmountPaid > 0),
    CONSTRAINT CHK_Payment_Method 
		CHECK (PaymentMethod IN ('Cash','Card','Online','Wallet'))
);