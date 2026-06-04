# ---------------------------------------------------------------------------
# Monitoring Module
# Creates:
#   - Container Insights for EKS (node + pod metrics)
#   - CloudWatch Dashboard templated per client
#   - CloudWatch Alarms: node CPU, node memory, pod restarts
#
# NOTE: The /aws/eks/<cluster>/cluster log group is created and owned by the
# EKS module. The observability addon uses it without conflict.
# ---------------------------------------------------------------------------

locals {
  name_prefix = "${var.client_name}-${var.environment}"
}

# ── Container Insights ────────────────────────────────────────────────────────

resource "aws_eks_addon" "observability" {
  cluster_name = var.cluster_name
  addon_name   = "amazon-cloudwatch-observability"

  tags = {
    Name = "${local.name_prefix}-observability-addon"
  }
}

# ── CloudWatch Dashboard ──────────────────────────────────────────────────────

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${local.name_prefix}-overview"

  dashboard_body = jsonencode({
    widgets = [
      # ── EKS Node CPU ──────────────────────────────────────────────────────
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "EKS Node CPU Utilization"
          region = var.aws_region
          view   = "timeSeries"
          metrics = [
            ["ContainerInsights", "node_cpu_utilization",
              "ClusterName", var.cluster_name,
              { stat = "Average", period = 60 }
            ]
          ]
          yAxis = { left = { min = 0, max = 100 } }
        }
      },
      # ── EKS Node Memory ───────────────────────────────────────────────────
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "EKS Node Memory Utilization"
          region = var.aws_region
          view   = "timeSeries"
          metrics = [
            ["ContainerInsights", "node_memory_utilization",
              "ClusterName", var.cluster_name,
              { stat = "Average", period = 60 }
            ]
          ]
          yAxis = { left = { min = 0, max = 100 } }
        }
      },
      # ── Pod Restarts ──────────────────────────────────────────────────────
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "Pod Restart Count"
          region = var.aws_region
          view   = "timeSeries"
          metrics = [
            ["ContainerInsights", "pod_number_of_container_restarts",
              "ClusterName", var.cluster_name,
              { stat = "Sum", period = 60 }
            ]
          ]
        }
      },
      # ── Running Pods ──────────────────────────────────────────────────────
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "Running Pod Count"
          region = var.aws_region
          view   = "timeSeries"
          metrics = [
            ["ContainerInsights", "pod_number_of_running_containers",
              "ClusterName", var.cluster_name,
              { stat = "Sum", period = 60 }
            ]
          ]
        }
      },
      # ── Node Disk ─────────────────────────────────────────────────────────
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6
        properties = {
          title  = "Node Filesystem Utilization"
          region = var.aws_region
          view   = "timeSeries"
          metrics = [
            ["ContainerInsights", "node_filesystem_utilization",
              "ClusterName", var.cluster_name,
              { stat = "Average", period = 60 }
            ]
          ]
          yAxis = { left = { min = 0, max = 100 } }
        }
      },
      # ── Network In/Out ────────────────────────────────────────────────────
      {
        type   = "metric"
        x      = 12
        y      = 12
        width  = 12
        height = 6
        properties = {
          title  = "Node Network Traffic"
          region = var.aws_region
          view   = "timeSeries"
          metrics = [
            ["ContainerInsights", "node_network_total_bytes",
              "ClusterName", var.cluster_name,
              { stat = "Sum", period = 60, label = "Total Bytes" }
            ]
          ]
        }
      }
    ]
  })
}

# ── CloudWatch Alarms ─────────────────────────────────────────────────────────

resource "aws_cloudwatch_metric_alarm" "node_cpu_high" {
  alarm_name          = "${local.name_prefix}-node-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "node_cpu_utilization"
  namespace           = "ContainerInsights"
  period              = 120
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "EKS node CPU above 80% for 4 minutes"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = var.cluster_name
  }

  alarm_actions = var.alarm_sns_arn != "" ? [var.alarm_sns_arn] : []
  ok_actions    = var.alarm_sns_arn != "" ? [var.alarm_sns_arn] : []

  tags = {
    Name = "${local.name_prefix}-node-cpu-high"
  }
}

resource "aws_cloudwatch_metric_alarm" "node_memory_high" {
  alarm_name          = "${local.name_prefix}-node-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "node_memory_utilization"
  namespace           = "ContainerInsights"
  period              = 120
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "EKS node memory above 80% for 4 minutes"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = var.cluster_name
  }

  alarm_actions = var.alarm_sns_arn != "" ? [var.alarm_sns_arn] : []
  ok_actions    = var.alarm_sns_arn != "" ? [var.alarm_sns_arn] : []

  tags = {
    Name = "${local.name_prefix}-node-memory-high"
  }
}

resource "aws_cloudwatch_metric_alarm" "pod_restarts_high" {
  alarm_name          = "${local.name_prefix}-pod-restarts-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "pod_number_of_container_restarts"
  namespace           = "ContainerInsights"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "More than 5 pod restarts in 5 minutes"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = var.cluster_name
  }

  alarm_actions = var.alarm_sns_arn != "" ? [var.alarm_sns_arn] : []

  tags = {
    Name = "${local.name_prefix}-pod-restarts-high"
  }
}

# ── Optional SNS Topic for Alarms ─────────────────────────────────────────────
# Created only if no external SNS ARN is provided

resource "aws_sns_topic" "alarms" {
  count = var.alarm_sns_arn == "" ? 1 : 0
  name  = "${local.name_prefix}-alarms"

  tags = {
    Name = "${local.name_prefix}-alarms"
  }
}
