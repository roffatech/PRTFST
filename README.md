PRTFST - Populate regular table from staging table. 

Summary of Procedure

    PROCEDURE PRTFST(@REG_TABLE, @STAGED_TABLE, @TRUNCATE_FLAG)
    
    @REG_TABLE            nvarchar(255)            The destination table that receives the data from @STAGED_TABLE
    @STAGED_TABLE         nvarchar(255)            The source table that has its data inserted into @REG_TABLE
    @TRUNCATE_FLAG        bit

Sample Invocation

    EXEC PRTFST 'CustomerTable', 'StagedCustomerTable', 0

    Creates and executes a dynamic SQL statement in the form:
    
        INSERT INTO CustomerTable([specific column list]) SELECT [specific column list] FROM StagedCustomerTable

    Which adds all data from StagedCustomerTable into CustomerTable. Because @TRUNCATE_FLAG is 0, CustomerTable will not be truncated beforehand.


Files included:

    PRTFST-process-and-data-flow.vsdx - VISIO diagram of process and data flow
    PRTFST-process-and-data-flow.pdf  - PDF equivalent of VISO diagram
    PRTFST.sql - source code for dropping and creating the stored procedure
    README.md - This README file


Background:

I often have to move data between two identically (or close enough) structured tables for a variety of reasons and while I could pull it off without manually writing lengthy INSERT INTO...SELECT FROM statements, it was still a tedious process. 

Yes, you can often use INSERT INTO DestTable SELECT * FROM SourceTable and be done with it, but I ran into some obstacles. 

Obstacle 1: If DestTable has an IDENTITY column, you cannot use INSERT INTO DestTable SELECT * FROM SourceTable, SQL Server will squawk about having to turn IDENTITY_INSERT ON and to use a specfic column list. 

So in those cases I was having to select from sys.columns and build a column list from the results. 

When I created these INSERT INTO DestTable([specific column list]) SELECT [specific column list] FROM SourceTable scripts, I kept them in a folder for reuse, but it soon became unmanageable. I could not find the right script when I just knew I had created one the other day. Sometimes I made the same script more than once and sometimes the structure of DestTable and SourceTable had changed since I last created the script for them. 

Obstacle 2: It became a pain in the neck to maintain these scripts for reuse. 

I also needed to TRUNCATE DestTable in many situations, but would forget. This would lead to PRIMARY KEY VIOLATIONs that were disruptive or worse, duplicate rows where uniqueness was not enforced. 

Obstacle 3: I often forgot to TRUNCATE DestTable when needed

Another problem was that I tried making some templates with a mix of hard-coded and variable sections, but this was problematic because not all tables have idenity columns, so setting the IDENTITY_INSERT value would be an error because it would not apply. 

Obstacle 4: I need to make sure the IDENTITY_INSERT property is set when it applies to a table and not referenced at all when it does not apply. 

Given these conditions, I made a stored proc PRTFST to create dynamic SQL to generate these statements. 

A. You can always run a statement in the form of INSERT INTO DestTable([specific column list]) SELECT [specific column list] FROM SourceTable with two compatible tables. So the dynamic SQL created by PRTFST always creates the dynamic SQL in this manner.

B. IDENTITY_INSERT code is omitted from the dynamic SQL statement when it does not apply and included when it does apply.

C. Truncating DestTable before data is added to it is controlled by a required parameter when invoking the stored proc, so I won't be so likely to forget that setting. 

D. There are no scripts of INSERT INTO DestTable([specific column list]) SELECT [specific column list] FROM SourceTable statements to maintain. 

In limited testing I have gotten this to work with several tables, with and without IDENTITY columns. 

You may be restricted from using this in an enterprise environment with security restrictions that limit access rights or have concerns about SQL injection and do not allow developers to use dynamic SQL. It should not be used in a production environment (hopefully the production environment would be configured to prevent it from running), but should be OK to use in a personal SSMS system, like one using Express or Developer editions. 
