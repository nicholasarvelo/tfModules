# This resource creates a scalable target representing the minimum and maximum
# number of tasks for the ECS service. You attach 'aws_appautoscaling_policy'
# resources to this resource.
resource "aws_appautoscaling_target" "this" {
  max_capacity = var.autoscaling_target.max_capacity
  min_capacity = var.autoscaling_target.min_capacity
  resource_id = (
    format(
      "service/%s/%s",
      var.ecs_service.cluster,
      aws_ecs_service.this.name
    )
  )
  scalable_dimension = var.autoscaling_target.scalable_dimension
  service_namespace  = var.autoscaling_target.service_namespace
  tags               = var.resource_tags
}

# This resource creates a scheduled action to scale in the ECS service. Scaling
# in means reducing the number of tasks running in the ECS service.
resource "aws_appautoscaling_scheduled_action" "scale_in" {
  count              = var.autoscaling_scheduled_scale_in.enable ? 1 : 0
  name               = var.autoscaling_scheduled_scale_in.name
  service_namespace  = aws_appautoscaling_target.this.service_namespace
  resource_id        = aws_appautoscaling_target.this.resource_id
  scalable_dimension = aws_appautoscaling_target.this.scalable_dimension
  schedule           = var.autoscaling_scheduled_scale_in.schedule
  timezone           = var.autoscaling_scheduled_scale_in.timezone

  scalable_target_action {
    min_capacity = var.autoscaling_scheduled_scale_in.min_capacity
    max_capacity = var.autoscaling_scheduled_scale_in.max_capacity
  }
}

# This resource creates a scheduled action to scale out the ECS service. Scaling
# out means increasing the number of tasks running in the ECS service.
resource "aws_appautoscaling_scheduled_action" "scale_out" {
  count              = var.autoscaling_scheduled_scale_out.enable ? 1 : 0
  name               = var.autoscaling_scheduled_scale_out.name
  service_namespace  = aws_appautoscaling_target.this.service_namespace
  resource_id        = aws_appautoscaling_target.this.resource_id
  scalable_dimension = aws_appautoscaling_target.this.scalable_dimension
  schedule           = var.autoscaling_scheduled_scale_out.schedule
  timezone           = var.autoscaling_scheduled_scale_out.timezone

  scalable_target_action {
    min_capacity = var.autoscaling_scheduled_scale_out.min_capacity
    max_capacity = var.autoscaling_scheduled_scale_out.max_capacity
  }
}
