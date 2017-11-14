#!/bin/bash

set -x
set -e

DIR=`dirname "$0"`
$DIR/install_hpfeeds-logger-json.sh

# install Java
apt-get install -y python-software-properties
add-apt-repository -y ppa:webupd8team/java
apt-get update
apt-get -y install oracle-java8-installer

# Install ES 2.4.5

wget -qO - https://packages.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -
echo "deb https://packages.elastic.co/elasticsearch/2.x/debian stable main" | sudo tee -a /etc/apt/sources.list.d/elasticsearch-2.x.list

apt-get update
apt-get install elasticsearch
sed -i '/network.host/c\network.host\:\ localhost' /etc/elasticsearch/elasticsearch.yml
echo 'threadpool.search.queue_size: 10000\n' >> /etc/elasticsearch/elasticsearch.yml
echo 'index.refresh_interval: 30s\n' >> /etc/elasticsearch/elasticsearch.yml
echo 'index.dynamic.mapper: false\n' >> /etc/elasticsearch/elasticsearch.yml
echo 'index.number_of_shards: 8' >> /etc/elasticsearch/elasticsearch.yml
export ES_JAVA_OPTS="-Dmapper.allow_dots_in_name=true"
service elasticsearch restart
update-rc.d elasticsearch defaults 95 10


# Install Kibana 4.6.4
mkdir /tmp/kibana
cd /tmp/kibana ;
wget https://download.elastic.co/kibana/kibana/kibana-4.6.4-linux-x86_64.tar.gz
tar xvf kibana-4.6.4-linux-x86_64.tar.gz
sed -i '/0.0.0.0/c\host\:\ localhost' /etc/elasticsearch/elasticsearch.yml
mkdir -p /opt/kibana
cp -R /tmp/kibana/kibana-4*/* /opt/kibana/
rm -rf /tmp/kibana/kibana-4*

cat > /etc/supervisor/conf.d/kibana.conf <<EOF
[program:kibana]
command=/opt/kibana/bin/kibana
directory=/opt/kibana/
stdout_logfile=/var/log/mhn/kibana.log
stderr_logfile=/var/log/mhn/kibana.err
autostart=true
autorestart=true
startsecs=10
EOF

# Install Logstash 2.4.1

echo "deb https://packages.elastic.co/logstash/2.4/debian stable main" | sudo tee -a /etc/apt/sources.list
apt-get update
apt-get install logstash
cd /opt/logstash

cat > /opt/logstash/mhn.conf <<EOF
input {
  file {
    path => "/var/log/mhn/mhn-json.log"
    start_position => "end"
    sincedb_path => "/opt/logstash/sincedb"
  }
}

filter {
  json {
    source => "message"
  }

  geoip {
      source => "src_ip"
      target => "src_ip_geo"
      database => "/opt/GeoLiteCity.dat"
      add_field => [ "[src_ip_geo][coordinates]", "%{[src_ip_geo][longitude]}" ]
      add_field => [ "[src_ip_geo][coordinates]", "%{[src_ip_geo][latitude]}"  ]
  }
  mutate {
    convert => [ "[src_ip_geo][coordinates]", "float"]
  }

  geoip {
    source => "dst_ip"
    target => "dst_ip_geo"
    database => "/opt/GeoLiteCity.dat"
    add_field => [ "[dst_ip_geo][coordinates]", "%{[dst_ip_geo][longitude]}" ]
    add_field => [ "[dst_ip_geo][coordinates]", "%{[dst_ip_geo][latitude]}"  ]
  }

  mutate {
      convert => [ "[dst_ip_geo][coordinates]", "float"]
    }
}

output {
  elasticsearch {
    hosts => localhost
    template => "/opt/logstash/mhn-template.json"
    template_overwrite => true
  }
}

EOF

cat > /opt/logstash/mhn-template.json <<EOF
{
    "template": "logstash-*",
    "version": 10001,
    "settings": {
        "number_of_shards": 5,
        "number_of_replicas": 0,
        "refresh_interval": "30s"
    },
        "mappings" : {
            "_default_" : {
                "properties" : {
                  "@timestamp" : {
                           "type" : "date",
                        "format" : "strict_date_optional_time||epoch_millis"
                    },
                    "@version" : {
                        "type" : "string",
                        "index": "not_analyzed"
                    },
                    "app" : {
                        "type" : "string",
                        "index": "not_analyzed"
                    },
                    "dest_ip" : {
                        "type" : "string",
                        "index": "not_analyzed"
                    },
                    "dest_port" : {
                        "type" : "long"
                      },
                    "direction" : {
                        "type" : "string",
                        "index": "not_analyzed"
                      },
                    "host" : {
                        "type" : "string",
                        "index": "not_analyzed"
                      },
                    "ids_type" : {
                        "type" : "string",
                        "index": "not_analyzed"
                      },
                    "message" : {
                        "type" : "string",
                        "index": "not_analyzed"
                      },
                    "path" : {
                        "type" : "string",
                        "index": "not_analyzed"
                      },
                    "protocol" : {
                        "type" : "string",
                        "index": "not_analyzed"
                      },
                    "sensor" : {
                        "type" : "string",
                        "index": "not_analyzed"
                      },
                    "severity" : {
                        "type" : "string",
                        "index": "not_analyzed"
                      },
                    "signature" : {
                        "type" : "string",
                        "index": "not_analyzed"
                      },
                    "src_ip" : {
                        "type" : "string",
                        "index": "not_analyzed"
                      },
                    "src_ip_geo" : {
                        "properties" : {
                          "area_code" : {
                              "type" : "long"
                          },
                          "city_name" : {
                              "type" : "string",
                              "index" : "not_analyzed"
                          },
                          "continent_code" : {
                              "type" : "string",
                              "index" : "not_analyzed"
                          },
                          "coordinates" : {
                              "type" : "double"
                          },
                          "country_code2" : {
                              "type" : "string",
                              "index" : "not_analyzed"
                          },
                          "country_code3" : {
                              "type" : "string",
                              "index" : "not_analyzed"
                          },
                          "country_name" : {
                              "type" : "string",
                              "index" : "not_analyzed"
                          },
                          "dma_code" : {
                              "type" : "long"
                          },
                          "ip" : {
                              "type" : "string",
                              "index" : "not_analyzed"
                          },
                          "latitude" : {
                              "type" : "double"
                          },
                          "location" : {
                              "type" : "geo_point"
                          },
                          "longitude" : {
                              "type" : "double"
                          },
                          "postal_code" : {
                              "type" : "string",
                              "index" : "not_analyzed"
                          },
                          "real_region_name" : {
                              "type" : "string",
                              "index" : "not_analyzed"
                          },
                          "region_name" : {
                              "type" : "string",
                              "index" : "not_analyzed"
                          },
                          "timezone" : {
                              "type" : "string",
                              "index" : "not_analyzed"
                          }
                      }
                  },
                  "src_port" : {
                      "type" : "long"
                  },
                  "ssh_password" : {
                      "type" : "string",
                      "index": "not_analyzed"
                  },
                  "ssh_username" : {
                      "type" : "string",
                      "index": "not_analyzed"
                  },
                  "ssh_version" : {
                      "type" : "string",
                      "index": "not_analyzed"
                  },
                  "timestamp" : {
                      "type" : "date",
                      "format" : "strict_date_optional_time||epoch_millis"
                  },
                  "transport" : {
                      "type" : "string",
                      "index": "not_analyzed"
                  },
                  "type" : {
                      "type" : "string",
                      "index": "not_analyzed"
                  },
                  "vendor_product" : {
                      "type" : "string",
                      "index": "not_analyzed"
                  },
                  "command" : {
                    "type" : "string",
                    "index" : "not_analyzed"
                  }
            }
        }        
    }
}
EOF

cat > /etc/supervisor/conf.d/logstash.conf <<EOF
[program:logstash]
command=/opt/logstash/bin/logstash -f mhn.conf
directory=/opt/logstash/
stdout_logfile=/var/log/mhn/logstash.log
stderr_logfile=/var/log/mhn/logstash.err
autostart=true
autorestart=true
startsecs=10
EOF

supervisorctl update
