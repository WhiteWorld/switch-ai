# switch-ai

AI API 配置快速切换工具，支持 Anthropic、OpenAI 等多服务一键切换。

## 依赖

- [yq](https://github.com/mikefarah/yq)（Go 版）或 `pip install yq`
- [fzf](https://github.com/junegunn/fzf)

## 安装

```bash
mkdir -p ~/.local/lib ~/.config/ai-keys
cp switch-ai.sh ~/.local/lib/
cp profiles.yaml ~/.config/ai-keys/
chmod 600 ~/.config/ai-keys/profiles.yaml
```

在 `~/.zshrc` 中添加：

```bash
echo 'source ~/.local/lib/switch-ai.sh' >> ~/.zshrc
echo 'alias ai="switch_ai"' >> ~/.zshrc
source ~/.zshrc
```

## 配置

编辑 `~/.config/ai-keys/profiles.yaml`：

```yaml
aigocode:
  ANTHROPIC_BASE_URL: https://api.example.com
  ANTHROPIC_AUTH_TOKEN: your-token

ark:
  ANTHROPIC_BASE_URL: https://ark.example.com/api
  ANTHROPIC_AUTH_TOKEN: your-token
  ANTHROPIC_MODEL: ark-code-latest
```

## 使用

```bash
ai                  # 交互式选择 profile（fzf 菜单）
ai <profile>        # 直接切换到指定 profile
ai show             # 查看当前生效的环境变量
ai clear            # 清除所有 AI 环境变量
```
