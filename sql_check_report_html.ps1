# Create an HTML Report from SQL Diagnostic queries
# Created by Richard Peterson

########################################

# Define the below variables

# Define folder path containing query result files
$queryFolderPath = "sqlcheck_results_localhost_test_20240511_235218"
# Define HTML file path
$htmlFilePath = "SQL Check Results.html"

########################################

# Create or overwrite the HTML file
$null = New-Item -Path $htmlFilePath -ItemType File -Force

# Create HTML header with the query folder path
$header = @"
<!DOCTYPE html>
<html>
<head>
    <title>sql_check</title>
    <style>
        table {
            border-collapse: collapse;
            width: 100%;
        }
        th, td {
            border: 1px solid black;
            padding: 8px;
            text-align: left;
        }
        th {
            background-color: #f2f2f2;
        }
    </style>
</head>
<body>
<h1>SQL Check Results</h1>
<h2>Folder: $queryFolderPath </h2?>
"@

# Add HTML header to the file
Add-Content -Path $htmlFilePath -Value $header

# Get list of query result files and sort them numerically
$queryFiles = Get-ChildItem -Path $queryFolderPath -Filter "*.tsv" | Sort-Object {[int]($_.BaseName -replace '(\d+)\..*', '$1')}

# Iterate through each query result file
foreach ($queryFile in $queryFiles) {
    # Get query category from file name (excluding extension)
    $queryCategory = $queryFile.BaseName
    
    # Read content of query result file
    $content = Get-Content -Path $queryFile.FullName
    
    # Convert content to HTML table
    $htmlTable = $content | ConvertFrom-Csv -Delimiter "`t" | ConvertTo-Html -Fragment
    
    # Add date and HTML table with subheading to the file
    Add-Content -Path $htmlFilePath -Value "<h2>$queryCategory</h2>"
    Add-Content -Path $htmlFilePath -Value $htmlTable
}

# Add HTML footer
$footer = @"
</body>
</html>
"@

# Add HTML footer to the file
Add-Content -Path $htmlFilePath -Value $footer

Write-Host "HTML report generated: $htmlFilePath"
