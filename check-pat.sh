#!/usr/bin/env bash

PAT=${PAT:-$1}

if [ -z "$PAT" ]; then
    printf "\e[0;31mError: GitHub Personal Access Token (PAT) not set\e[0m\n"
    exit 1
fi

response=$(curl -s -H "Authorization: token $PAT" https://api.github.com/user)
if echo "$response" | grep -q '"message": "Bad credentials"'; then
    printf "\e[0;31mError: Invalid personal access token (PAT)\e[0m\n"
    exit 1
else
    printf "\e[0;32mOK: GitHub Personal Access Token (PAT) is valid\e[0m\n"
    exit 0
fi
