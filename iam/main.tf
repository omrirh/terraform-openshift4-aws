locals {
  arn = "aws"
}

data "aws_partition" "current" {}

resource "aws_iam_instance_profile" "worker" {
  name = "disconnected-ipi-worker-profile"

  role = aws_iam_role.worker_role.name
}

resource "aws_iam_role" "worker_role" {
  name = "disconnected-ipi-worker-role"
  path = "/"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
                "Service": "ec2.${data.aws_partition.current.dns_suffix}"
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF

  tags = merge(
    {
      "Name" = "disconnected-ipi-worker-role"
    },
    var.tags,
  )
}

resource "aws_iam_role_policy" "worker_policy" {
  name = "disconnected-ipi-worker-policy"
  role = aws_iam_role.worker_role.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeInstances",
        "ec2:DescribeRegions"
      ],
      "Resource": "*"
    }
  ]
}
EOF

}

