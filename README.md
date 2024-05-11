# Pages

`build/users.list` 中添加用户，每行一个，文件必须以 `\n` 结尾
`build/users_pubkeys` 中添加用户的公钥 `{user}.pub`

`docker build . -t pages`

`docker compose up`

在 `~/www` 中创建网站目录，如 `~/www/example.com`
