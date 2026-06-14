CREATE TABLE Employees (
    EmployeeID INT IDENTITY(1,1),
    EmpName VARCHAR(100) NOT NULL,
    JobRole VARCHAR(50) NOT NULL, 
	
	CONSTRAINT PK_Employees PRIMARY KEY (EmployeeID)
);

CREATE TABLE RoomTypes (
    RoomTypeID INT IDENTITY(1,1),
    TypeName VARCHAR(50) NOT NULL, 
    NightlyPrice DECIMAL(10, 2) NOT NULL,

	CONSTRAINT PK_RoomTypes PRIMARY KEY (RoomTypeID)
);

CREATE TABLE Guests (
    GuestID INT IDENTITY(1,1),
    FullName VARCHAR(150) NOT NULL,
    NationalID_Passport VARCHAR(50) UNIQUE NOT NULL,
    Phone VARCHAR(20),
    Email VARCHAR(100),
    City VARCHAR(50),

	CONSTRAINT PK_Guests PRIMARY KEY (GuestID)
);

CREATE TABLE Services (
    ServiceID INT IDENTITY(1,1),
    ServiceName VARCHAR(100) NOT NULL, 
    Price DECIMAL(10, 2) NOT NULL,

	CONSTRAINT PK_Services PRIMARY KEY (ServiceID)
);


CREATE TABLE Rooms (
    RoomID INT IDENTITY(1,1),
    RoomNumber VARCHAR(10) NOT NULL UNIQUE,
    RoomTypeID INT,
    AvailabilityStatus VARCHAR(20) DEFAULT 'Available', 

    CONSTRAINT PK_Rooms PRIMARY KEY (RoomID),
    CONSTRAINT FK_Rooms_RoomTypes FOREIGN KEY (RoomTypeID) REFERENCES RoomTypes(RoomTypeID)
);

CREATE TABLE HousekeepingLogs (
    LogID INT IDENTITY(1,1),
    RoomID INT,
    CleaningDate DATE NOT NULL,
    StartTime TIME,
    EndTime TIME,

    CONSTRAINT PK_HousekeepingLogs PRIMARY KEY (LogID),
    CONSTRAINT FK_Housekeeping_Rooms FOREIGN KEY (RoomID) REFERENCES Rooms(RoomID)
);

CREATE TABLE Reservations (
    ReservationID INT IDENTITY(1,1),
    GuestID INT,
    RoomID INT,
    EmployeeID INT, 
    CheckInDate DATE NOT NULL,
    CheckOutDate DATE NOT NULL,
    BookedNightlyPrice DECIMAL(10, 2) NOT NULL,
    ReservationStatus VARCHAR(20) DEFAULT 'Booked', 
    CancellationReason VARCHAR(255) NULL,

    CONSTRAINT PK_Reservations PRIMARY KEY (ReservationID),
    CONSTRAINT FK_Reservations_Guests FOREIGN KEY (GuestID) REFERENCES Guests(GuestID),
    CONSTRAINT FK_Reservations_Rooms FOREIGN KEY (RoomID) REFERENCES Rooms(RoomID),
    CONSTRAINT FK_Reservations_Employees FOREIGN KEY (EmployeeID) REFERENCES Employees(EmployeeID)
);

CREATE TABLE ServiceUsages (
    UsageID INT IDENTITY(1,1),
    ReservationID INT,
    ServiceID INT,
    UsageDate DATE NOT NULL,
    Quantity INT DEFAULT 1,
    TotalCharge DECIMAL(10, 2) NOT NULL, -- (الكمية × السعر)

  
    CONSTRAINT PK_ServiceUsages PRIMARY KEY (UsageID),
    CONSTRAINT FK_ServiceUsages_Reservations FOREIGN KEY (ReservationID) REFERENCES Reservations(ReservationID),
    CONSTRAINT FK_ServiceUsages_Services FOREIGN KEY (ServiceID) REFERENCES Services(ServiceID)
);

CREATE TABLE Invoices (
    InvoiceID INT IDENTITY(1,1),
    ReservationID INT,
    InvoiceDate DATE NOT NULL,
    TotalRoomCharge DECIMAL(10, 2) NOT NULL, 
    TotalServicesCharge DECIMAL(10, 2) DEFAULT 0.00, 
    DiscountAmount DECIMAL(10, 2) DEFAULT 0.00, 
    NetTotalAmount DECIMAL(10, 2) NOT NULL, 
    PaidAmount DECIMAL(10, 2) DEFAULT 0.00,

	CONSTRAINT PK_Invoices PRIMARY KEY (InvoiceID),
    CONSTRAINT FK_Invoices_Reservations FOREIGN KEY (ReservationID) REFERENCES Reservations(ReservationID)
);

CREATE TABLE Payments (
    PaymentID INT IDENTITY(1,1),
    InvoiceID INT,
    EmployeeID INT,
    PaymentDate DATE NOT NULL,
    AmountPaid DECIMAL(10, 2) NOT NULL,
    PaymentMethod VARCHAR(50), 
    PaymentStatus VARCHAR(20) DEFAULT 'Completed', 

    CONSTRAINT PK_Payments PRIMARY KEY (PaymentID),
    CONSTRAINT FK_Payments_Invoices FOREIGN KEY (InvoiceID) REFERENCES Invoices(InvoiceID),
    CONSTRAINT FK_Payments_Employees FOREIGN KEY (EmployeeID) REFERENCES Employees(EmployeeID)
);