# Tron server

This module can be used to deploy Tron server in AWS. It creates the following resources:

- An ASG to run Tron and automatically redeploy it if it crashes
- An EBS volume for the Tron database directory mounted to /data that persists between redeploys (GRUNTWORK MODULE)
- An ALB to route traffic to Tron
- A Route 53 DNS A record for Tron pointing at the ALB
- Path-Based listeners for FullNode & SolidityNode gRPC API



## Tron AMI

See the packer build file in packer/tron-server.json for a way to create an AMI and script you can run in User Data to start Tron while the server is booting.



## IAM permissions

This module assigns an IAM role to the Tron server and exports the ID of the IAM role. To give your Tron server IAM permissions—e.g., so you can use the server to automatically deploy changes into your AWS account—you can attach permissions to the IAM role using the [aws_iam_role_policy resource](https://www.terraform.io/docs/providers/aws/r/iam_role_policy.html):

```hcl
module "tron-server" {
  source = "git::git@github.com:Example/infra-live-modules//terraform/aws/_modules/module-server/tron-server?ref=master"
  
  # ... (params ommitted) ...
}

resource "aws_iam_role_policy" "example" {
  role   = "${module.tron.tron_iam_role_id}"
  policy = "${data.aws_iam_policy_document.example.json}"
}

data "aws_iam_policy_document" "example" {
  statement {
    effect    = "Allow"
    actions   = ["s3:*"]
    resources = "*"
  }
}
```