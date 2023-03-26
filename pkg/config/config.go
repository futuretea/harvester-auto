package config

type Slack struct {
	BotToken string           `mapstructure:"bot_token"`
	AppToken string           `mapstructure:"app_token"`
	Users    map[string]uint8 `mapstructure:"users"`
}

type Config struct {
	Slack Slack `mapstructure:"slack"`
}
