#!/usr/bin/env bash
# bucket
export ui_bucket_endpoint="oss-cn-hangzhou.aliyuncs.com"
export ui_bucket_name="harvester-dev"
# dashboard
export ui_dashboard_bucket_dir="bot-dashboard"
export ui_dashboard_output_target="oss://${ui_bucket_name}/${ui_dashboard_bucket_dir}"
export ui_dashboard_base_url="https://${ui_bucket_name}.${ui_bucket_endpoint}/${ui_dashboard_bucket_dir}"
# rancher dashboard
export ui_rancher_dashboard_bucket_dir="bot-rancher-dashboard"
export ui_rancher_dashboard_output_target="oss://${ui_bucket_name}/${ui_rancher_dashboard_bucket_dir}"
export ui_rancher_dashboard_base_url="https://${ui_bucket_name}.${ui_bucket_endpoint}/${ui_rancher_dashboard_bucket_dir}"
# plugin
export ui_plugin_bucket_dir="bot-plugin"
export ui_plugin_output_target="oss://${ui_bucket_name}/${ui_plugin_bucket_dir}"
export ui_plugin_base_url="https://${ui_bucket_name}.${ui_bucket_endpoint}/${ui_plugin_bucket_dir}"
# code
export ui_base_branch="master"
