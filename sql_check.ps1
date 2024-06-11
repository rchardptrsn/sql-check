# SQL Check
# Created by Richard Peterson


# ##########################################

# Run queries from file 'sql_queries.psm1' against a database targeted in your env.txt file.
# Creates a file for each query with query name and timestamp

# Examples:

# .\sql_check.ps1 -UseIntegratedSecurity # uses the active user to log in to SQl

# .\sql_check.ps1 # Loads login params from an env.txt file.

# ##########################################

# Script parameter to use integrated security in the connection string or not.
[CmdletBinding()]
param (
    [switch]$UseIntegratedSecurity
)

# Load parameters from environment file
$envFile = "env.txt"
$envParams = Get-Content -Path $envFile | ForEach-Object {
    $paramName, $paramValue = $_ -split '=', 2
    $paramName = $paramName.Trim()
    $paramValue = $paramValue.Trim()
    [PSCustomObject]@{
        Name = $paramName
        Value = $paramValue
    }
}

# Create hash table for parameters
$params = @{}
foreach ($param in $envParams) {
    $params[$param.Name] = $param.Value
}

# Assign connection parameters from the environment file
$server = "$($params["server"]),$($params["port"])"
$database = $params["database"]
$username = $params["username"]
$password = $params["password"]

# ##########################################

# Configuration and Imports

# Start with a clean environment
Remove-Module -Name sql_queries -Force

# Import the module containing SQL queries
Import-Module .\sql_queries.psm1

# Define the timestamp
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

# Define the results folder path including server, database, and timestamp
$resultsFolderPath = Join-Path -Path $PSScriptRoot -ChildPath ("sqlcheck_results_{0}_{1}_{2}" -f $params["server"], $database, $timestamp)

# Create the results folder if it doesn't exist
if (-not (Test-Path -Path $resultsFolderPath)) {
    New-Item -Path $resultsFolderPath -ItemType Directory -Force | Out-Null
}

# ##########################################

# Define the query categories and corresponding functions

$queries = [ordered]@{
    "OS Machine" = "Get-OSMachine"
    "SQL Version" = "Get-SQLVersion"
    "Cores NumaNodes" = "Get-CoresNumaNodes"
    "Parallelism" = "Get-Parallelism"
    "Process Memory" = "Get-ProcessMemory"
    "Memory Details" = "Get-MemoryDetails"
    "File Latency" = "Get-FileLatency"
    "File Autogrowth_Options" = "Get-AutoGrowth"
    "tempdb" = "Get-tempdb"
    "Auto Create Stats" = "Get-AutoCreateStats"
    "Stats Updates" = "Get-StatsUpdates"
    "Automatic Tuning Options" = "Get-AutomaticTuningOptions"
    "Recent Full Backups" = "Get-RecentFullBackups"
    "Top Waits" = "Get-TopWaits"
    # Add more query categories and functions as needed
}

# ##########################################

# Connect to the database and execute the defined queries

# Create connection string
if ($UseIntegratedSecurity) {
    $connectionString = "Server=$server;Database=$database;Integrated Security=True;"
} else {
    $connectionString = "Server=$server;Database=$database;User ID=$username;Password=$password;"
}

# Create a connection to SQL Server
$connection = New-Object System.Data.SqlClient.SqlConnection
$connection.ConnectionString = $connectionString

try {
    # Attempt to open the connection
    $connection.Open()
    # Initialize file counter
    $fileCounter = 1

    # Loop through queries and execute them
    foreach ($queryCategory in $queries.Keys) {
        # Get the function name for the query
        $queryFunction = $queries[$queryCategory]

        # Call the function to retrieve the query
        $query = (Get-Command $queryFunction).ScriptBlock.Invoke()

        # Create a command
        $command = $connection.CreateCommand()
        $command.CommandText = $query

        # Execute the query
        $result = $command.ExecuteReader()

        # Output the results to a file with timestamp in the file name
        $fileName = "$fileCounter. $queryCategory" + ".tsv"
        $filePath = Join-Path -Path $resultsFolderPath -ChildPath $fileName

        $table = New-Object System.Data.DataTable
        $table.Load($result)
        $table | Export-Csv -Path $filePath -Delimiter "`t" -NoTypeInformation -Encoding UTF8

        Write-Host "Results for $queryCategory saved to $filePath"

        # Increment file counter
        $fileCounter++
    }
} catch {
    Write-Host "An error occurred: $_"
} finally {
    # Close the connection
    if ($connection.State -eq 'Open') {
        $connection.Close()
    }
}
