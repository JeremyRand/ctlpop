# Copyright 2020 Jeremy Rand.

# This file is part of CTLPop.
#
# CTLPop is free software: you can redistribute it and/or
# modify it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# CTLPop is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with CTLPop.  If not, see
# <https://www.gnu.org/licenses/>.

param (
  $sync_dir
)

# Measure initial count of certs
$initial_cert_count = (& certutil -store AuthRoot | Select-String -Pattern "=== Certificate \d+ ===" | Measure-Object -Line).Lines + (& certutil -store Root | Select-String -Pattern "=== Certificate \d+ ===" | Measure-Object -Line).Lines

# Download the new certs
& certutil -v -syncWithWU -f -f "$sync_dir"
If (!$?) {
  Write-Host "syncWithWU failed!  Is your network connection down?"
  exit 1
}

# Get the list of new certs
$cert_files = Get-ChildItem "$sync_dir" -Filter "*.crt" | Sort-Object

# Measure count of new certs
$downloaded_cert_count = ($cert_files | Measure-Object -Line).Lines
If (0 -eq $downloaded_cert_count) {
  Write-Host "No certs downloaded from WU!  Is your network connection down?"
  exit 1
}

# Import the new certs to the store
:CERT foreach ($single_cert in $cert_files) {
  Write-Host $single_cert.Name
  foreach ( $TryNum in 1..10 ) {
    & certutil -verify $single_cert.FullName | Out-Null
    If (!$?) {
      Write-Host "Failed to import cert!  Retrying..."
      Start-Sleep -seconds 5
      continue
    }
    $cert_key_authroot = "HKLM:\SOFTWARE\Microsoft\SystemCertificates\AuthRoot\Certificates\" + $single_cert.Name.split(".")[0]
    $cert_key_root = "HKLM:\SOFTWARE\Microsoft\SystemCertificates\Root\Certificates\" + $single_cert.Name.split(".")[0]
    If ( -not (Test-Path "$cert_key_authroot") -and -not (Test-Path "$cert_key_root") ) {
      Write-Host "Import had no effect!  Retrying..."
      Start-Sleep -seconds 5
      continue
    }
    # Success with this cert, move onto the next cert.
    continue CERT
  }
  exit 1
}

# Measure final count of certs
$final_cert_count = (& certutil -store AuthRoot | Select-String -Pattern "=== Certificate \d+ ===" | Measure-Object -Line).Lines + (& certutil -store Root | Select-String -Pattern "=== Certificate \d+ ===" | Measure-Object -Line).Lines
$diff_cert_count = $final_cert_count - $initial_cert_count

Write-Host "----- Results -----"
Write-Host "----- Initial certs: $initial_cert_count -----"
Write-Host "----- Downloaded certs: $downloaded_cert_count -----"
Write-Host "----- Final certs: $final_cert_count -----"
Write-Host "----- Diff (Final-Initial): $diff_cert_count -----"
