/* A small invoicing schema in SQL Server's idiom: bracketed names and types,
   IDENTITY keys, named PRIMARY KEY CLUSTERED constraints, and the foreign keys
   declared afterwards the way a scripted database emits them. Paste your own
   schema over it, or drop a .sql file anywhere on this window. */

CREATE TABLE [dbo].[Employee](
    [EmployeeId]  [int] IDENTITY(1,1) NOT NULL,
    [ManagerId]   [int] NULL,                  -- a table may point at itself
    [FirstName]   [nvarchar](40) NOT NULL,
    [LastName]    [nvarchar](40) NOT NULL,
    [HiredOn]     [date] NOT NULL,
 CONSTRAINT [PK_Employee] PRIMARY KEY CLUSTERED ([EmployeeId] ASC)
);

CREATE TABLE [dbo].[Customer](
    [CustomerId]    [int] IDENTITY(1,1) NOT NULL,
    [SupportRepId]  [int] NULL,
    [CompanyName]   [nvarchar](80) NULL,
    [Email]         [nvarchar](120) NOT NULL,
    [CreatedOn]     [datetime2](3) NOT NULL,
 CONSTRAINT [PK_Customer] PRIMARY KEY CLUSTERED ([CustomerId] ASC)
);

CREATE TABLE [dbo].[Address](
    [AddressId]   [int] IDENTITY(1,1) NOT NULL,
    [CustomerId]  [int] NOT NULL,
    [Line1]       [nvarchar](120) NOT NULL,
    [City]        [nvarchar](60) NOT NULL,
    [PostalCode]  [nvarchar](12) NULL,
    [Country]     [char](2) NOT NULL,
 CONSTRAINT [PK_Address] PRIMARY KEY CLUSTERED ([AddressId] ASC)
);

CREATE TABLE [dbo].[Product](
    [ProductId]  [int] IDENTITY(1,1) NOT NULL,
    [Sku]        [nvarchar](32) NOT NULL,
    [Name]       [nvarchar](120) NOT NULL,
    [UnitPrice]  [numeric](10, 2) NOT NULL,
 CONSTRAINT [PK_Product] PRIMARY KEY CLUSTERED ([ProductId] ASC)
);

CREATE TABLE [dbo].[StockLevel](
    [ProductId]  [int] NOT NULL,
    [OnHand]     [int] NOT NULL,
    [Reserved]   [int] NOT NULL,
 CONSTRAINT [PK_StockLevel] PRIMARY KEY CLUSTERED ([ProductId] ASC)
);

CREATE TABLE [dbo].[Invoice](
    [InvoiceId]         [int] IDENTITY(1,1) NOT NULL,
    [CustomerId]        [int] NOT NULL,
    [BillingAddressId]  [int] NULL,
    [InvoiceNumber]     [nvarchar](24) NOT NULL,
    [IssuedOn]          [date] NOT NULL,
    [Total]             [numeric](12, 2) NOT NULL,
 CONSTRAINT [PK_Invoice] PRIMARY KEY CLUSTERED ([InvoiceId] ASC)
);

CREATE TABLE [dbo].[InvoiceLine](
    [InvoiceLineId]  [int] IDENTITY(1,1) NOT NULL,
    [InvoiceId]      [int] NOT NULL,
    [ProductId]      [int] NOT NULL,
    [Quantity]       [int] NOT NULL,
    [UnitPrice]      [numeric](10, 2) NOT NULL,
 CONSTRAINT [PK_InvoiceLine] PRIMARY KEY CLUSTERED ([InvoiceLineId] ASC)
);

CREATE TABLE [dbo].[Payment](
    [PaymentId]  [int] IDENTITY(1,1) NOT NULL,
    [InvoiceId]  [int] NOT NULL,
    [Method]     [nvarchar](24) NOT NULL,
    [Reference]  [uniqueidentifier] NOT NULL,
    [PaidOn]     [datetime2](3) NOT NULL,
    [Amount]     [numeric](12, 2) NOT NULL,
 CONSTRAINT [PK_Payment] PRIMARY KEY CLUSTERED ([PaymentId] ASC)
);

ALTER TABLE [dbo].[Employee] ADD CONSTRAINT [FK_EmployeeManager]
    FOREIGN KEY([ManagerId]) REFERENCES [dbo].[Employee] ([EmployeeId]);

ALTER TABLE [dbo].[Customer] ADD CONSTRAINT [FK_CustomerSupportRep]
    FOREIGN KEY([SupportRepId]) REFERENCES [dbo].[Employee] ([EmployeeId]);

ALTER TABLE [dbo].[Address] ADD CONSTRAINT [FK_AddressCustomer]
    FOREIGN KEY([CustomerId]) REFERENCES [dbo].[Customer] ([CustomerId]);

ALTER TABLE [dbo].[StockLevel] ADD CONSTRAINT [FK_StockLevelProduct]
    FOREIGN KEY([ProductId]) REFERENCES [dbo].[Product] ([ProductId]);

ALTER TABLE [dbo].[Invoice] ADD CONSTRAINT [FK_InvoiceCustomer]
    FOREIGN KEY([CustomerId]) REFERENCES [dbo].[Customer] ([CustomerId]);

ALTER TABLE [dbo].[Invoice] ADD CONSTRAINT [FK_InvoiceBillingAddress]
    FOREIGN KEY([BillingAddressId]) REFERENCES [dbo].[Address] ([AddressId]);

ALTER TABLE [dbo].[InvoiceLine] ADD CONSTRAINT [FK_InvoiceLineInvoice]
    FOREIGN KEY([InvoiceId]) REFERENCES [dbo].[Invoice] ([InvoiceId]);

ALTER TABLE [dbo].[InvoiceLine] ADD CONSTRAINT [FK_InvoiceLineProduct]
    FOREIGN KEY([ProductId]) REFERENCES [dbo].[Product] ([ProductId]);

ALTER TABLE [dbo].[Payment] ADD CONSTRAINT [FK_PaymentInvoice]
    FOREIGN KEY([InvoiceId]) REFERENCES [dbo].[Invoice] ([InvoiceId]);
