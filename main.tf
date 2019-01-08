resource "aws_iam_role" "sns" {
  name = "${var.name_prefix}-lifecycle-sns"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "autoscaling.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

# creating policy document and attaching as inline policies instead of using the AutoScalingNotificationAccessRole
# managed policy due to Terraform issue https://github.com/hashicorp/terraform/issues/5979.

data "aws_iam_policy_document" "auto_scaling_notification_access" {
  statement {
    actions = [
      "sqs:SendMessage",
      "sqs:GetQueueUrl",
      "sns:Publish",
    ]

    resources = [
      "*",
    ]
  }
}

resource "aws_iam_role_policy" "asg_notification_sns" {
  name   = "${var.name_prefix}-lifecycle-sns-permissions"
  role   = "${aws_iam_role.sns.id}"
  policy = "${data.aws_iam_policy_document.auto_scaling_notification_access.json}"
}

resource "aws_iam_role" "lambda" {
  name = "${var.name_prefix}-lifecycle-lambda"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

data "aws_iam_policy_document" "lambda" {
  statement {
    actions = [
      "autoscaling:CompleteLifecycleAction",
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "ec2:DescribeInstances",
      "ec2:DescribeInstanceAttribute",
      "ec2:DescribeInstanceStatus",
      "ec2:DescribeHosts",
      "ecs:ListContainerInstances",
      "ecs:SubmitContainerStateChange",
      "ecs:SubmitTaskStateChange",
      "ecs:DescribeContainerInstances",
      "ecs:UpdateContainerInstancesState",
      "ecs:ListTasks",
      "ecs:DescribeTasks",
      "sns:Publish",
      "sns:ListSubscriptions",
    ]

    resources = [
      "*",
    ]
  }
}

resource "aws_iam_role_policy" "lambda" {
  name   = "${var.name_prefix}-lambda-lifecycle-policy"
  role   = "${aws_iam_role.lambda.id}"
  policy = "${data.aws_iam_policy_document.lambda.json}"
}

resource "aws_iam_role_policy" "asg_notification_lambda" {
  name   = "${var.name_prefix}-lambda-sns-policy"
  role   = "${aws_iam_role.lambda.id}"
  policy = "${data.aws_iam_policy_document.auto_scaling_notification_access.json}"
}

data "archive_file" "index" {
  type        = "zip"
  source_dir  = "${path.module}/index"
  output_path = "${path.module}/files/index.zip"
}

data "null_data_source" "path-to-some-file" {
  inputs {
    filename = "${substr("${path.module}/files/index.zip", length(path.cwd) + 1, -1)}"
  }
}

resource "aws_lambda_function" "lambda" {
  function_name = "${var.name_prefix}-lifecycle-lambda"
  runtime       = "python2.7"
  filename      = "${data.null_data_source.path-to-some-file.outputs.filename}"
  role          = "${aws_iam_role.lambda.arn}"
  handler       = "index.lambda_handler"

  source_code_hash = "${data.archive_file.index.output_base64sha256}"

  lifecycle {
    # A workaround when running this code on different machines is to ignore changes, as described here:
    # https://github.com/hashicorp/terraform/issues/7613#issuecomment-241603087
    ignore_changes = [
      "filename",
      "last_modified",
      "source_code_hash",
    ]
  }
}

resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name              = "/aws/lambda/${aws_lambda_function.lambda.function_name}"
  retention_in_days = "${var.log_retention_in_days}"
}

resource "aws_lambda_permission" "sns" {
  statement_id  = "AllowExecutionFromSNS"
  function_name = "${aws_lambda_function.lambda.arn}"
  action        = "lambda:InvokeFunction"
  principal     = "sns.amazonaws.com"
  source_arn    = "${aws_sns_topic.asg_sns.arn}"
}

resource "aws_sns_topic" "asg_sns" {
  name = "${var.name_prefix}-lifecycle-hook"
}

resource "aws_sns_topic_subscription" "asg_sns" {
  topic_arn = "${aws_sns_topic.asg_sns.arn}"
  protocol  = "lambda"
  endpoint  = "${aws_lambda_function.lambda.arn}"
}

resource "aws_autoscaling_lifecycle_hook" "terminate" {
  name                    = "${var.name_prefix}-terminations"
  autoscaling_group_name  = "${var.autoscaling_group_name}"
  default_result          = "${var.hook_default_result}"
  heartbeat_timeout       = "${var.hook_heartbeat_timeout}"
  lifecycle_transition    = "autoscaling:EC2_INSTANCE_TERMINATING"
  notification_target_arn = "${aws_sns_topic.asg_sns.arn}"
  role_arn                = "${aws_iam_role.sns.arn}"
}
