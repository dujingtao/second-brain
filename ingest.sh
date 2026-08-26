#!/bin/bash
set -e
cd /home/ubuntu/second-brain

git pull --quiet origin main

claude -p "按照 CLAUDE.md 的规则，处理 raw/ 目录下所有还没被wiki引用过的新文件，在wiki/生成或更新对应页面，如果没有新文件就什么都不用做，完成后用git commit和push保存"
