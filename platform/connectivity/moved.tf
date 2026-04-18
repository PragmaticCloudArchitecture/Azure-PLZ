# This file is populated with moved {} blocks before applying a major-version module upgrade.
#
# Upgrade workflow:
#   1. Update version in main.tf, run terraform init -upgrade
#   2. Run terraform plan — note any resource replacements in the DNS zone VNet links
#   3. Read the module output:
#        terraform output -raw private_link_private_dns_zone_virtual_network_link_moved_blocks
#   4. Paste the emitted moved {} blocks into this file
#   5. Run terraform plan again — verify zero destroys on the VNet link resources
#   6. Run terraform apply
#
# Keep this file empty between upgrades.
