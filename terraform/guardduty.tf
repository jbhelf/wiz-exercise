########################################
# guardduty.tf
#
# Create a GuardDuty detector (enabling GuardDuty)
########################################

resource "aws_guardduty_detector" "this" {
  enable = true
}