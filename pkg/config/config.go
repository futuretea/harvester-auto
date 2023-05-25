package config

type Slack struct {
	BotToken string            `mapstructure:"bot_token"`
	AppToken string            `mapstructure:"app_token"`
	Envs     map[string]string `mapstructure:"envs"`
	Users    []*User           `mapstructure:"users"`
}

type Config struct {
	Slack Slack `mapstructure:"slack"`
}

type User struct {
	Name        string `mapstructure:"name"`
	NamespaceID uint8  `mapstructure:"namespace"`
	Mode        string `mapstructure:"mode"`
}

const (
	ModeRW = "rw"
	ModeRO = "ro"
)
