# Define folder path containing query result files
$queryFolderPath = "DMV_Queries"

# Define Markdown file path
$markdownFilePath = "DMV_Report.md"

# Create or overwrite the Markdown file
$null = New-Item -Path $markdownFilePath -ItemType File -Force

# Get list of query result files
$queryFiles = Get-ChildItem -Path $queryFolderPath -Filter "*.tsv"

# Iterate through each query result file
foreach ($queryFile in $queryFiles) {
    # Get query category from file name (excluding extension)
    $queryCategory = $queryFile.BaseName
    
    # Read content of query result file
    $content = Get-Content -Path $queryFile.FullName
    
    # Format content as Markdown table
    $markdownTable = $content | ConvertFrom-Csv -Delimiter "`t" | ConvertTo-Markdown -Table
    
    # Write Markdown content to Markdown file
    Add-Content -Path $markdownFilePath -Value "## $queryCategory`n$markdownTable`n"
}

Write-Host "Markdown report generated: $markdownFilePath"