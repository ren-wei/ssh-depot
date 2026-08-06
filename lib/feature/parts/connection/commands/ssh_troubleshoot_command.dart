import 'package:ssh_depot/feature/utils/shell_quote.dart';

String troubleshootCommandFor(String? publicKey) {
  final quotedKey = shellQuote(publicKey ?? '');
  return '''
set -u
echo "== SSH 连接排查 =="
echo "[提示] 请在应用里填写的同一个 SSH 用户下执行本命令。"
echo "[提示] 本命令排查目标机账户、公钥和 sshd 配置；网络、端口、防火墙仍需在本机用 ssh -vvv 排查。"
echo

problems=0
current_user=\$(id -un 2>/dev/null || whoami)
home_dir="\${HOME:-}"
if [ -z "\$home_dir" ] && command -v getent >/dev/null 2>&1; then
  home_dir=\$(getent passwd "\$current_user" | cut -d: -f6)
fi
ssh_dir="\$home_dir/.ssh"
authorized_keys="\$ssh_dir/authorized_keys"
expected_key=$quotedKey

echo "[用户] \$current_user"
echo "[HOME] \$home_dir"
echo

if [ -z "\$home_dir" ]; then
  echo "原因: 无法识别当前用户 HOME 目录。"
  problems=\$((problems + 1))
elif [ ! -d "\$ssh_dir" ]; then
  echo "原因: \$ssh_dir 不存在。需要先创建并授权本机公钥。"
  problems=\$((problems + 1))
else
  ssh_perm=\$(stat -c "%a" "\$ssh_dir" 2>/dev/null || echo "?")
  ssh_owner=\$(stat -c "%U" "\$ssh_dir" 2>/dev/null || echo "?")
  echo "[检查] \$ssh_dir 权限=\$ssh_perm 所有者=\$ssh_owner"
  if [ "\$ssh_perm" != "700" ]; then
    echo "原因: \$ssh_dir 权限不是 700，sshd 可能拒绝读取。修复: chmod 700 ~/.ssh"
    problems=\$((problems + 1))
  fi
  if [ "\$ssh_owner" != "\$current_user" ]; then
    echo "原因: \$ssh_dir 所有者不是当前用户。修复: chown \$current_user:\$current_user ~/.ssh"
    problems=\$((problems + 1))
  fi
fi

if [ ! -f "\$authorized_keys" ]; then
  echo "原因: \$authorized_keys 不存在。需要把本机公钥追加进去。"
  problems=\$((problems + 1))
else
  key_perm=\$(stat -c "%a" "\$authorized_keys" 2>/dev/null || echo "?")
  key_owner=\$(stat -c "%U" "\$authorized_keys" 2>/dev/null || echo "?")
  echo "[检查] \$authorized_keys 权限=\$key_perm 所有者=\$key_owner"
  if [ "\$key_perm" != "600" ]; then
    echo "原因: authorized_keys 权限不是 600，sshd 可能拒绝读取。修复: chmod 600 ~/.ssh/authorized_keys"
    problems=\$((problems + 1))
  fi
  if [ "\$key_owner" != "\$current_user" ]; then
    echo "原因: authorized_keys 所有者不是当前用户。修复: chown \$current_user:\$current_user ~/.ssh/authorized_keys"
    problems=\$((problems + 1))
  fi
  if [ -n "\$expected_key" ]; then
    if grep -qxF "\$expected_key" "\$authorized_keys"; then
      echo "[检查] authorized_keys 已包含本机公钥"
    else
      echo "原因: authorized_keys 未包含本机公钥。请重新执行“复制授权命令”。"
      problems=\$((problems + 1))
    fi
  else
    echo "[跳过] 未带入本机公钥，无法检查 authorized_keys 是否包含正确公钥。"
  fi
fi

if command -v sshd >/dev/null 2>&1; then
  effective=\$(sshd -T -C user="\$current_user",host=localhost,addr=127.0.0.1 2>/dev/null || true)
  if [ -n "\$effective" ]; then
    pubkey_auth=\$(printf "%s\\n" "\$effective" | awk '/^pubkeyauthentication / {print \$2; exit}')
    password_auth=\$(printf "%s\\n" "\$effective" | awk '/^passwordauthentication / {print \$2; exit}')
    authorized_file=\$(printf "%s\\n" "\$effective" | awk '/^authorizedkeysfile / {for (i=2; i<=NF; i++) printf "%s%s", (i==2 ? "" : " "), \$i; print ""; exit}')
    echo "[检查] PubkeyAuthentication=\${pubkey_auth:-unknown}"
    echo "[检查] PasswordAuthentication=\${password_auth:-unknown}"
    echo "[检查] AuthorizedKeysFile=\${authorized_file:-unknown}"
    if [ "\${pubkey_auth:-yes}" = "no" ]; then
      echo "原因: sshd 禁用了公钥认证。需要在 sshd 配置中启用 PubkeyAuthentication。"
      problems=\$((problems + 1))
    fi
  else
    echo "[提示] sshd -T 无法读取有效配置，改用配置文件关键词检查。"
  fi
else
  echo "[提示] 未找到 sshd 命令，跳过 sshd 有效配置检查。"
fi

config_hits=\$(grep -hE "^[[:space:]]*(PubkeyAuthentication|PasswordAuthentication|PermitRootLogin|AuthorizedKeysFile)[[:space:]]+" /etc/ssh/sshd_config /etc/ssh/sshd_config.d/*.conf 2>/dev/null || true)
if [ -n "\$config_hits" ]; then
  echo
  echo "[sshd 配置片段]"
  printf "%s\\n" "\$config_hits"
fi

echo
if [ "\$problems" -eq 0 ]; then
  echo "未在目标机账户、公钥和 sshd 基础配置中发现明显问题。"
  echo "下一步请在本机执行: ssh -vvv \$current_user@<服务器地址> 'echo __ssh-depot_ok__'"
else
  echo "发现 \$problems 个可能原因，请按上方原因修复后重新测试连接。"
fi
'''
      .trim();
}
