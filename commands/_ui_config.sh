#!/usr/bin/env bash
ui_workspace_root="/ui_workspace"
ui_logs_dir="${ui_workspace_root}/logs"
# bucket
ui_bucket_endpoint="oss-cn-hangzhou.aliyuncs.com"
ui_bucket_name="harvester-dev"
# dashboard
ui_dashboard_bucket_dir="bot-dashboard"
ui_dashboard_output_target="oss://${ui_bucket_name}/${ui_dashboard_bucket_dir}"
ui_dashboard_base_url="https://${ui_bucket_name}.${ui_bucket_endpoint}/${ui_dashboard_bucket_dir}"
# plugin
ui_plugin_bucket_dir="bot-plugin"
ui_plugin_output_target="oss://${ui_bucket_name}/${ui_plugin_bucket_dir}"
ui_plugin_base_url="https://${ui_bucket_name}.${ui_bucket_endpoint}/${ui_plugin_bucket_dir}"
