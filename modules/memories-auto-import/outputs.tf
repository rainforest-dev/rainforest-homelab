output "label" {
  description = "launchd label of the job"
  value       = local.plist_label
}

output "plist_path" {
  description = "Installed LaunchAgent plist"
  value       = local.plist_path
}

output "runner_dir" {
  description = "Checkout the job runs from"
  value       = local.runner_dir
}

output "runner_ref" {
  description = "Commit the runner is pinned to"
  value       = var.runner_ref
}

output "log_dir" {
  description = "Directory holding stdout.log and stderr.log"
  value       = local.log_dir
}

output "state_file" {
  description = "State the job writes after each run"
  value       = "${pathexpand(var.data_dir)}/auto-import/state.json"
}

output "kickstart_command" {
  description = "Starts one run now"
  value       = "launchctl kickstart -k gui/$(id -u)/${local.plist_label}"
}
