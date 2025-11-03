DROP PROCEDURE IF EXISTS PRTFST
GO

-- PRTFST
--
-- Originally called PopRegTableFromStagedTable
--
-- Quick way to add data from a staged table to a regular 
-- table with the same structure in the same database. It's
-- a utility stored proc that I would not normally keep in 
-- a production environment, but it saves me time in 
-- development. 
--
-- to invoke this you would run the following:
--
-- EXEC PRTFST <regular table> <staged table> <truncate flag>
--
-- where:
--
-- <regular table> is the destination table to be populated
--
-- <staged table> is the source table containing the data we 
-- want to populate <regular table> with
--
-- <truncate flag> if set to 1, will truncate <regular table>
-- before receiving data from <staged table> otherwise it won't
-- be truncated.
--
-- Additional comments:
--
-- Yes, you can pretty much accomplish the same thing by running
-- INSERT INTO <regular table> SELECT * FROM <staged table>
-- but not if <regular table> has an identity column. 
--
-- In those situations you have to use a column list showing
-- specific column names and have to turn IDENTITY_INSERT on
-- before the insert statement. 
--
-- Since you can use a specified column list in an 
-- INSERT INTO <regular table> SELECT * FROM <staged table>
-- statement with any table, regardless of whether it has
-- an identity column or not, I use this for all staged-to-regular
-- table inserts. 
--


CREATE PROCEDURE PRTFST
(
	@REG_TABLE nvarchar(255),
	@STAGED_TABLE nvarchar(255),
	@TRUNCATE_FLAG bit
)
AS

BEGIN
	BEGIN TRY
		DECLARE
			@HAS_IDENTITY bit,
			@ERRMSG varchar(500),
			@CRLF nvarchar(2) = CHAR(13) + CHAR(10),
			@TAB nvarchar(1) = CHAR(9),
			@COL_SEP nvarchar(4),
			@COLUMN_LIST nvarchar(MAX),
			@SQL nvarchar(MAX);

		-- Test the table parameters to see if the tables exist, if not, start building
		-- an error message, then throw an error. We're catching this before SQL Server does.
		SET @ERRMSG = '';

		IF OBJECT_ID(@REG_TABLE) IS NULL
			SET @ERRMSG = @ERRMSG + 'Destination table ' + @REG_TABLE + ' not found ' + @CRLF;

		IF OBJECT_ID(@STAGED_TABLE) IS NULL
			SET @ERRMSG = @ERRMSG + 'Source table ' + @STAGED_TABLE + ' not found ' + @CRLF;

		-- Just using a generic error number I saw in an example somewhere,
		-- 50001 has no special meaning to me otherwise as an error number. 
		IF @ERRMSG <> ''
			THROW 50001, @ERRMSG, 1;

		-- CREATE the dynamic SQL

		-- set an indicator to allow us to add code to turn IDENTITY_INSERT on and off
		-- for tables with an identity column
		SELECT @HAS_IDENTITY = OBJECTPROPERTY(OBJECT_ID(@REG_TABLE), 'TableHasIdentity');

		SET @COL_SEP = ', ' + @CRLF; 

		-- I had problems getting the next query to sort by the column order 
		-- in the table definition. SQL Server complained that you cannot order 
		-- by sys.columns.column_id because that column is not in the SELECT
		-- list. 
		-- 
		-- But you cannot include that column in the SELECT list because 
		-- you cannot select a value into a column in the same statement as
		-- a call to STRING_AGG. 
		--
		-- No harm no foul though. If the column list is not in the preferred order, 
		-- that's OK as long as the column list is the same in the INSERT INTO part 
		-- as it is in the SELECT...FROM part

		SELECT
			@COLUMN_LIST = STRING_AGG(QUOTENAME(c.name), @COL_SEP)  
		FROM
			sys.columns c
		WHERE
			c.object_id = OBJECT_ID(@REG_TABLE);

		
		-- indent the columns in the columnlist, because
		-- I have some Adrian Monk in me
		SELECT @COLUMN_LIST = REPLACE(@COLUMN_LIST, '[', @TAB + '[');

		SET @SQL = ''

		-- this is the truncate option from when the stored proc is invoked
		IF @TRUNCATE_FLAG = 1
			SET @SQL = @SQL + 'TRUNCATE TABLE ' + @REG_TABLE + ';' + @CRLF + @CRLF;

		-- Add code to turn identity insert on when we have identity column
		IF @HAS_IDENTITY = 1
			SET @SQL = @SQL + 'SET IDENTITY_INSERT ' + @REG_TABLE + ' ON' + @CRLF + @CRLF;

		SET @SQL = @SQL + 'INSERT INTO ' + @REG_TABLE + @CRLF;
		SET @SQL = @SQL + '(' + @CRLF;
		SET @SQL = @SQL + @COLUMN_LIST + @CRLF;
		SET @SQL = @SQL + ')' + @CRLF 
		SET @SQL = @SQL + 'SELECT' + @CRLF;
		SET @SQL = @SQL + @COLUMN_LIST + @CRLF;
		SET @SQL = @SQL + 'FROM ' + @STAGED_TABLE + @CRLF + @CRLF;

		-- Add code to turn identity insert off when we have identity column
		IF @HAS_IDENTITY = 1
			SET @SQL = @SQL + 'SET IDENTITY_INSERT ' + @REG_TABLE + ' OFF' + @CRLF;

		-- execute the dynamic SQL we created. Some environments may prevent you
		-- doing this as a security measure against SQL injection attacks. I use 
		-- this normally on my personal systems and am not concerned about that.
		EXEC sp_executesql @SQL;

	END TRY
	BEGIN CATCH
        -- Handle the error
        SELECT 
            ERROR_NUMBER() AS ErrorNumber,
            ERROR_MESSAGE() AS ErrorMessage,
            ERROR_SEVERITY() AS ErrorSeverity,
            ERROR_STATE() AS ErrorState,
            ERROR_PROCEDURE() AS ErrorProcedure,
            ERROR_LINE() AS ErrorLine;
        
        -- Optionally re-throw the error
        THROW;
	END CATCH
END

