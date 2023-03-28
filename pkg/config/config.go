package config

type Slack struct {
	BotToken string            `mapstructure:"bot_token"`
	AppToken string            `mapstructure:"app_token"`
	Envs     map[string]string `mapstructure:"envs"`
	Users    map[string]uint8  `mapstructure:"users"`
}

type Config struct {
	Slack Slack `mapstructure:"slack"`
}
