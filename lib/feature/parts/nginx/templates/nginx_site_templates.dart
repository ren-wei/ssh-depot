import 'package:ssh_depot/feature/classes/nginx_template_definition.dart';

const reverseProxyTemplate = '''
server {
    listen 80;
    server_name {{domain}};

    location / {
        proxy_pass http://{{upstream_host}}:{{upstream_port}};
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
''';

String staticSiteTemplate(bool enableLogs) {
  return '''
server {
    listen 80;
    server_name {{domain}};
    root {{root_path}};
    index index.html index.htm;

    location / {
        try_files \$uri \$uri/ =404;
    }
${enableLogs ? '''
    access_log /var/log/nginx/{{domain}}_access.log;
    error_log /var/log/nginx/{{domain}}_error.log;
''' : ''}
}
''';
}

const builtInWebsiteTemplates = [
  NginxTemplateDefinition(
    id: 'static_site',
    name: '静态网站',
    type: '静态站点',
    description: '标准 root + try_files 配置',
    builtIn: true,
    content: '''
server {
    listen 80;
    server_name {{domain}};
    root {{root_path}};
    index index.html index.htm;

    location / {
        try_files \$uri \$uri/ =404;
    }

    access_log /var/log/nginx/{{domain}}_access.log;
    error_log /var/log/nginx/{{domain}}_error.log;
}
''',
  ),
  NginxTemplateDefinition(
    id: 'reverse_proxy',
    name: '反向代理',
    type: '反向代理',
    description: '转发到本机上游服务',
    builtIn: true,
    content: reverseProxyTemplate,
  ),
];
