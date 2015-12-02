# resources/user.rb
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
# Resource for InfluxDB user

property :username, String, name_property: true
property :password, String
property :databases, Array, default: []
property :permissions, Array, default: []
property :auth_username, String, default: 'root'
property :auth_password, String, default: 'root'

# Added this so that we can deal with tcp connection resets
# See: https://github.com/getoutreach/outreach-issues/issues/347
def retry_on_exception(max_attempts, start_pause, multiplier, &block)
  t = 0
  pause = start_pause
  begin
    t += 1
    yield
  rescue StandardError => ex
    if t <= max_attempts 
      Chef::Log.warn("Encountered exception on attempt ##{t}; pausing for #{pause} seconds and retrying (#{ex})")
      sleep(pause)
      pause *= multiplier
      retry
    else
      raise
    end
  end
end

action :create do
  unless password
    Chef::Log.fatal('You must provide a password for the :create action on this resource')
  end
  retry_on_exception(5, 1, 2.0) do
    databases.each do |db|
      unless client.list_users.map { |x| x['username'] || x['name'] }.member?(username)
        client.create_database_user(db, username, password)
        updated_by_last_action true
      end
      permissions.each do |permission|
        client.grant_user_privileges(username, db, permission)
        updated_by_last_action true
      end
    end
  end
end

action :update do
  client.update_user_password(username, password) if password
  databases.each do |db|
    permissions.each do |permission|
      client.grant_user_privileges(username, db, permission)
    end
  end
  updated_by_last_action true
end

action :delete do
  if client.list_users.map { |x| x['username'] || x['name'] }.member?(username)
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
