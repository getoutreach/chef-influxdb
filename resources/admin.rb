# resources/admin.rb
#
# Author: Simple Finance <ops@simple.com>
# License: Apache License, Version 2.0
#
# Copyright 2013 Simple Finance Technology Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Resource for InfluxDB cluster admin

property :username, String, name_property: true
property :password, String
property :auth_username, String, default: 'root'
property :auth_password, String, default: 'root'

action :create do
  unless password
    Chef::Log.fatal('You must provide a password for the :create action on this resource!')
  end

  begin
    unless client.list_cluster_admins.member?(username)
      client.create_cluster_admin(username, password)
      updated_by_last_action true
    end
  rescue InfluxDB::AuthenticationError => e
    # Exception due to missing admin user
    # https://influxdb.com/docs/v0.9/administration/authentication.html
    # https://github.com/chrisduong/chef-influxdb/commit/fe730374b4164e872cbf208c06d2462c8a056a6a
    if e.to_s.include? 'create admin user'
      client.create_cluster_admin(username, password)
      updated_by_last_action true
    end
  end
end

action :update do
  unless password
    Chef::Log.fatal('You must provide a password for the :update action on this resource!')
  end

  client.update_user_password(username, password)
  updated_by_last_action true
end

action :delete do
  if client.list_cluster_admins.member?(username)
    client.delete_user(username)
    updated_by_last_action true
  end
end

def client
  require 'influxdb'
  @client ||=
    InfluxDB::Client.new(
      username: auth_username,
      password: auth_password,
      retry: 10
    )
end
