/* SQL Server: bracketed identifiers everywhere, including the types, and
   PRIMARY KEY CLUSTERED with a sort direction inside the column list. */

CREATE TABLE [dbo].[Customer](
    [CustomerId] [int] IDENTITY(1,1) NOT NULL,
    [FirstName] [nvarchar](40) NOT NULL,
    [Email] [nvarchar](60) NULL,
    [SupportRepId] [int] NULL,
 CONSTRAINT [PK_Customer] PRIMARY KEY CLUSTERED ([CustomerId] ASC)
);

CREATE TABLE [dbo].[Invoice](
    [InvoiceId] [int] IDENTITY(1,1) NOT NULL,
    [CustomerId] [int] NOT NULL,
    [BillingAddress] [nvarchar](70) NULL,
    [Total] [numeric](10, 2) NOT NULL,
 CONSTRAINT [PK_Invoice] PRIMARY KEY CLUSTERED ([InvoiceId] ASC)
);

ALTER TABLE [dbo].[Invoice] ADD CONSTRAINT [FK_InvoiceCustomer]
    FOREIGN KEY([CustomerId]) REFERENCES [dbo].[Customer] ([CustomerId]);
