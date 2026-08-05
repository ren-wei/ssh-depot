import 'package:ssh_depot/feature/parts/nginx/templates/template_manifest.dart';

const builtInNginxTemplates = [
  TemplateManifest(
    id: 'static_site',
    name: '静态网站',
    variables: [
      TemplateVariable(
        name: 'domain',
        type: TemplateVariableType.string,
        label: '域名',
      ),
      TemplateVariable(
        name: 'root_path',
        type: TemplateVariableType.string,
        label: '网站根目录',
      ),
      TemplateVariable(
        name: 'enable_logs',
        type: TemplateVariableType.boolean,
        label: '开启日志',
      ),
    ],
  ),
  TemplateManifest(
    id: 'reverse_proxy',
    name: '反向代理',
    variables: [
      TemplateVariable(
        name: 'domain',
        type: TemplateVariableType.string,
        label: '域名',
      ),
      TemplateVariable(
        name: 'upstream_host',
        type: TemplateVariableType.string,
        label: '后端地址',
      ),
      TemplateVariable(
        name: 'upstream_port',
        type: TemplateVariableType.number,
        label: '后端端口',
      ),
    ],
  ),
];
