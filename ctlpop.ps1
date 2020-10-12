param (
  $sync_dir
)

# Measure initial count of certs
$initial_cert_count = (& certutil -store AuthRoot | Select-String -Pattern "=== Certificate \d+ ===" | Measure-Object -Line).Lines

# Download the new certs
& certutil -v -syncWithWU -f -f "$sync_dir"

# Get the list of new certs
$cert_files = Get-ChildItem "$sync_dir" -Filter "*.crt"

# Measure count of new certs
$downloaded_cert_count = ($cert_files | Measure-Object -Line).Lines

# Import the new certs to the store
foreach ($single_cert in $cert_files) {
  & certutil -verify $single_cert.FullName
}

# Measure final count of certs
$final_cert_count = (& certutil -store AuthRoot | Select-String -Pattern "=== Certificate \d+ ===" | Measure-Object -Line).Lines
$diff_cert_count = $final_cert_count - $initial_cert_count

Write-Host "----- Results -----"
Write-Host "----- Initial certs: $initial_cert_count -----"
Write-Host "----- Downloaded certs: $downloaded_cert_count -----"
Write-Host "----- Final certs: $final_cert_count -----"
Write-Host "----- Diff (Final-Initial): $diff_cert_count -----"
