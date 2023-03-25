package main

import (
	"context"
	"errors"
	"fmt"
	"github.com/spf13/viper"
	"log"
	"os"
	"os/exec"
	"strings"

	"github.com/shomali11/slacker"
	"github.com/sirupsen/logrus"
)

type Slack struct {
	BotToken string           `mapstructure:"bot_token"`
	AppToken string           `mapstructure:"app_token"`
	Users    map[string]uint8 `mapstructure:"users"`
}

type Config struct {
	Slack Slack `mapstructure:"slack"`
}

var config Config

var blackList = []string{
	"..",
	"&",
	";",
}

const (
	EventTypeMessage = "message"
	CommandsDir      = "commands"
	ConfigDir        = "configs"
)

func init() {
	// config
	viper.SetConfigName("config")
	viper.SetConfigType("yaml")
	viper.AddConfigPath(ConfigDir)
	if err := viper.ReadInConfig(); err != nil {
		panic(fmt.Errorf("fatal error config file: %w", err))
	}
	if err := viper.Unmarshal(&config); err != nil {
		panic(fmt.Errorf("unable to decode into struct, %w", err))
	}
	// log
	logrus.SetFormatter(&logrus.JSONFormatter{})
	logrus.SetLevel(logrus.WarnLevel)
}

var userID2clusterID = map[uint8]uint8{}

func getClusterID(userID uint8) uint8 {
	return userID2clusterID[userID]
}

func setClusterID(userID uint8, clusterID uint8) {
	userID2clusterID[userID] = clusterID
}

func getUserIDByUserName(userName string) (uint8, bool) {
	name, exist := config.Slack.Users[userName]
	return name, exist
}

func replyOpt(botCtx slacker.BotContext) slacker.ReplyOption {
	return slacker.WithThreadReply(botCtx.Event().Type != EventTypeMessage)
}

func replyErrorOpt(botCtx slacker.BotContext) slacker.ReportErrorOption {
	return slacker.WithThreadError(botCtx.Event().Type != EventTypeMessage)
}

func shellCheck(bashCommand string) bool {
	for _, s := range blackList {
		if strings.Contains(bashCommand, s) {
			return false
		}
	}
	return true
}

func shell2Reply(botCtx slacker.BotContext, response slacker.ResponseWriter, bashCommand string) {
	useThread := botCtx.Event().Type != EventTypeMessage
	logrus.Debugln(bashCommand)
	if !shellCheck(bashCommand) {
		err := errors.New("unknown command")
		logrus.Error(err)
		response.ReportError(err, slacker.WithThreadError(useThread))
		return
	}

	cmd := exec.Command("/usr/bin/bash", strings.Split(bashCommand, " ")...)
	cmd.Env = os.Environ()
	cmd.Dir = CommandsDir
	output, err := cmd.Output()
	if err != nil {
		logrus.Error(err)
		response.ReportError(err, slacker.WithThreadError(useThread))
		return
	}
	outputStr := string(output)
	if outputStr == "" {
		outputStr = "done"
	}
	logrus.Error(response.Reply(outputStr, slacker.WithThreadReply(useThread)))
}

func clusterNotSetReply(botCtx slacker.BotContext, response slacker.ResponseWriter) {
	err := errors.New("the current cluster id is not set, run the `cluster {clusterID}` command to set the current cluster id ")
	response.ReportError(err, replyErrorOpt(botCtx))
}

func main() {
	// new bot
	bot := slacker.NewClient(config.Slack.BotToken, config.Slack.AppToken)
	authorizationFunc := func(botCtx slacker.BotContext, request slacker.Request) bool {
		logrus.Info(botCtx.Event())
		_, exist := getUserIDByUserName(botCtx.Event().UserName)
		return exist
	}

	// command hi
	hiDefinition := &slacker.CommandDefinition{
		Description: "Hi!",
		Examples:    []string{"hi"},
		Handler: func(botCtx slacker.BotContext, request slacker.Request, response slacker.ResponseWriter) {
			text := fmt.Sprintf("Hi, %s", botCtx.Event().UserName)
			logrus.Error(response.Reply(text, replyOpt(botCtx)))
		},
	}
	bot.Command("hi", hiDefinition)

	// command ping
	pingDefinition := &slacker.CommandDefinition{
		Description:       "Ping!",
		Examples:          []string{"ping"},
		AuthorizationFunc: authorizationFunc,
		Handler: func(botCtx slacker.BotContext, request slacker.Request, response slacker.ResponseWriter) {
			logrus.Error(response.Reply("pong", replyOpt(botCtx)))
		},
	}
	bot.Command("ping", pingDefinition)

	// command pr2c
	pr2cDefinition := &slacker.CommandDefinition{
		Description:       "Create Harvester cluster after merge PR",
		Examples:          []string{"pr2c 3670 0"},
		AuthorizationFunc: authorizationFunc,
		Handler: func(botCtx slacker.BotContext, request slacker.Request, response slacker.ResponseWriter) {
			harvesterPRs := request.StringParam("harvesterPRs", "0")
			harvesterInstallerPRs := request.StringParam("harvesterInstallerPRs", "0")
			userID, _ := getUserIDByUserName(botCtx.Event().UserName)
			clusterID := getClusterID(userID)
			if clusterID == 0 {
				clusterNotSetReply(botCtx, response)
				return
			}
			bashCommand := fmt.Sprintf("./pr2c.sh %s %s %d %d", harvesterPRs, harvesterInstallerPRs, userID, clusterID)
			shell2Reply(botCtx, response, bashCommand)
		},
	}
	bot.Command("pr2c {harvesterPRs} {harvesterInstallerPRs}", pr2cDefinition)

	// command v2c
	v2cDefinition := &slacker.CommandDefinition{
		Description:       "Create Harvester cluster after download ISO",
		Examples:          []string{"v2c v1.1"},
		AuthorizationFunc: authorizationFunc,
		Handler: func(botCtx slacker.BotContext, request slacker.Request, response slacker.ResponseWriter) {
			harvesterVersion := request.StringParam("harvesterVersion", "0")
			userID, _ := getUserIDByUserName(botCtx.Event().UserName)
			clusterID := getClusterID(userID)
			if clusterID == 0 {
				clusterNotSetReply(botCtx, response)
				return
			}
			bashCommand := fmt.Sprintf("./v2c.sh %s %d %d", harvesterVersion, userID, clusterID)
			shell2Reply(botCtx, response, bashCommand)
		},
	}
	bot.Command("v2c {harvesterVersion}", v2cDefinition)

	// command url
	urlDefinition := &slacker.CommandDefinition{
		Description:       "Show Harvester cluster url",
		Examples:          []string{"url"},
		AuthorizationFunc: authorizationFunc,
		Handler: func(botCtx slacker.BotContext, request slacker.Request, response slacker.ResponseWriter) {
			userID, _ := getUserIDByUserName(botCtx.Event().UserName)
			clusterID := getClusterID(userID)
			if clusterID == 0 {
				clusterNotSetReply(botCtx, response)
				return
			}
			bashCommand := fmt.Sprintf("./url.sh %d %d", userID, clusterID)
			shell2Reply(botCtx, response, bashCommand)
		},
	}
	bot.Command("url", urlDefinition)

	// command tail
	tailDefinition := &slacker.CommandDefinition{
		Description:       "Tail Harvester cluster logs",
		Examples:          []string{"tail", "tail 100"},
		AuthorizationFunc: authorizationFunc,
		Handler: func(botCtx slacker.BotContext, request slacker.Request, response slacker.ResponseWriter) {
			userID, _ := getUserIDByUserName(botCtx.Event().UserName)
			clusterID := getClusterID(userID)
			if clusterID == 0 {
				clusterNotSetReply(botCtx, response)
				return
			}
			lineNumber := request.IntegerParam("lineNumber", 10)
			bashCommand := fmt.Sprintf("./tail.sh %d %d %d", userID, clusterID, lineNumber)
			shell2Reply(botCtx, response, bashCommand)
		},
	}
	bot.Command("tail {lineNumber}", tailDefinition)

	// command version
	versionDefinition := &slacker.CommandDefinition{
		Description:       "Show Harvester version",
		Examples:          []string{"version"},
		AuthorizationFunc: authorizationFunc,
		Handler: func(botCtx slacker.BotContext, request slacker.Request, response slacker.ResponseWriter) {
			userID, _ := getUserIDByUserName(botCtx.Event().UserName)
			clusterID := getClusterID(userID)
			if clusterID == 0 {
				clusterNotSetReply(botCtx, response)
				return
			}
			bashCommand := fmt.Sprintf("./version.sh %d %d", userID, clusterID)
			shell2Reply(botCtx, response, bashCommand)
		},
	}
	bot.Command("version", versionDefinition)

	// command destroy
	destroyDefinition := &slacker.CommandDefinition{
		Description:       "Destroy Harvester cluster nodes",
		Examples:          []string{"destroy"},
		AuthorizationFunc: authorizationFunc,
		Handler: func(botCtx slacker.BotContext, request slacker.Request, response slacker.ResponseWriter) {
			userID, _ := getUserIDByUserName(botCtx.Event().UserName)
			clusterID := getClusterID(userID)
			if clusterID == 0 {
				clusterNotSetReply(botCtx, response)
				return
			}
			bashCommand := fmt.Sprintf("./destroy.sh %d %d", userID, clusterID)
			shell2Reply(botCtx, response, bashCommand)
		},
	}
	bot.Command("destroy", destroyDefinition)

	// command virsh
	virshDefinition := &slacker.CommandDefinition{
		Description:       "virsh command warpper",
		Examples:          []string{"virsh list"},
		AuthorizationFunc: authorizationFunc,
		Handler: func(botCtx slacker.BotContext, request slacker.Request, response slacker.ResponseWriter) {
			command := request.StringParam("command", "")
			args := request.StringParam("args", "")
			bashCommand := fmt.Sprintf("./virsh.sh %s %s", command, args)
			shell2Reply(botCtx, response, bashCommand)
		},
	}
	bot.Command("virsh {command} {args}", virshDefinition)

	// command ps
	psDefinition := &slacker.CommandDefinition{
		Description:       "Show Harvester cluster status",
		Examples:          []string{"ps"},
		AuthorizationFunc: authorizationFunc,
		Handler: func(botCtx slacker.BotContext, request slacker.Request, response slacker.ResponseWriter) {
			userID, _ := getUserIDByUserName(botCtx.Event().UserName)
			bashCommand := fmt.Sprintf("./ps.sh %d", userID)
			shell2Reply(botCtx, response, bashCommand)
		},
	}
	bot.Command("ps", psDefinition)

	// command cluster
	clusterDefinition := &slacker.CommandDefinition{
		Description:       "Show/Set Current Harvester cluster",
		Examples:          []string{"cluster (show current cluster id)", "cluster 1 (set current cluster id to 1)"},
		AuthorizationFunc: authorizationFunc,
		Handler: func(botCtx slacker.BotContext, request slacker.Request, response slacker.ResponseWriter) {
			userID, _ := getUserIDByUserName(botCtx.Event().UserName)
			var clusterID uint8
			clusterID = uint8(request.IntegerParam("clusterID", 0))
			if clusterID == 0 {
				clusterID = getClusterID(userID)
			} else {
				setClusterID(userID, clusterID)
			}
			if clusterID == 0 {
				clusterNotSetReply(botCtx, response)
				return
			}
			text := fmt.Sprintf("current cluster id is %d", clusterID)
			logrus.Error(response.Reply(text, replyOpt(botCtx)))
		},
	}
	bot.Command("cluster {clusterID}", clusterDefinition)

	// bot run
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	err := bot.Listen(ctx)
	if err != nil {
		log.Fatal(err)
	}
}
