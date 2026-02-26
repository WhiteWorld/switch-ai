# 1. 安装脚本
mkdir -p ~/.local/lib ~/.config/ai-keys
cp switch-ai.sh ~/.local/lib/
cp profiles.yaml ~/.config/ai-keys/
chmod 600 ~/.config/ai-keys/profiles.yaml

# 2. 在 ~/.zshrc 中加载函数（不进入交互模式）
echo 'source ~/.local/lib/switch-ai.sh' >> ~/.zshrc
echo 'alias ai="switch_ai"' >> ~/.zshrc
source ~/.zshrc

# 3. 使用（source 后不会自动进入交互模式）
ai                    # 交互选择（需要时才进入）
ai sssaicode          # 直接切换
ai clear              # 清除变量
ai show               # 查看变量
clear_ai_env          # 清除变量（函数直接调用）
show_ai_env           # 查看变量（函数直接调用）
