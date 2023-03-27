package main

import (
	"context"
	"fmt"
	"log"
	"strings"

	"github.com/shomali11/slacker"
	"github.com/sirupsen/logrus"
	"github.com/spf13/viper"

	"github.com/futuretea/harvester-auto/pkg/config"
	"github.com/futuretea/harvester-auto/pkg/constants"
	"github.com/futuretea/harvester-auto/pkg/user"
	"github.com/futuretea/harvester-auto/pkg/util"
)

var (
	conf         config.Config
	userContexts = map[uint8]*user.Context{}
)

func init() {
	// config
	viper.SetConfigName("config")
	viper.SetConfigType("yaml")
	viper.AddConfigPath(constants.ConfigDir)
	if err := viper.ReadInConfig(); err != nil {
		panic(fmt.Errorf("fatal error config file: %w", err))
	}
	if err := viper.Unmarshal(&conf); err != nil {
		panic(fmt.Errorf("unable to decode into struct, %w", err))
	}
	// log
	logrus.SetFormatter(&logrus.JSONFormatter{})
	logrus.SetLevel(logrus.WarnLevel)
}

func getUserContext(userID uint8) *user.Context {
	return userContexts[userID]
}

func setUserContext(userID uint8, userContext *user.Context) {
	userContexts[userID] = userContext
}

func getUserIDByUserName(userName string) (uint8, bool) {
	name, exist := conf.Slack.Users[userName]
	return name, exist
}

func main() {
	// new bot
	bot := slacker.NewClient(conf.Slack.BotToken, conf.Slack.AppToken)
	authorizationFunc := func(botCtx slacker.BotContext, request slacker.Request) bool {
		userName := botCtx.Event().UserName
		text := botCtx.Event().Text
		userID, exist := getUserIDByUserName(userName)
		if !exist {
			logrus.Infof("unknown user: %s", userName)
			return false
		}
		userContext := getUserContext(userID)
		if userContext == nil {
			userContext = user.CreateContext(0, text)
			setUserContext(userID, userContext)
		} else {
			userContext.Record(text)
		}
		return true
	}

	// command ping
	pingDefinition := &slacker.CommandDefinition{
		Description:       "Ping!",
		Examples:          []string{"ping"},
		AuthorizationFunc: authorizationFunc,
		Handler: func(botCtx slacker.BotContext, request slacker.Request, response slacker.ResponseWriter) {
			logrus.Error(response.Reply("pong", util.ReplyOpt(botCtx)))
		},
	}
	bot.Command("ping", pingDefinition)

	// command c
	clusterDefinition := &slacker.CommandDefinition{
		Description:       "Show/Set Current Harvester cluster",
		Examples:          []string{"c (show current cluster id)", "c 1 (set current cluster id to 1)"},
		AuthorizationFunc: authorizationFunc,
		Handler: func(botCtx slacker.BotContext, request slacker.Request, response slacker.ResponseWriter) {
			userID, _ := getUserIDByUserName(botCtx.Event().UserName)
			userContext := getUserContext(userID)
			requestClusterID := uint8(request.IntegerParam("clusterID", 0))
			if requestClusterID != 0 {
				userContext.SetClusterID(requestClusterID)
			}
			clusterID := userContext.GetClusterID()
			if clusterID == 0 {
				util.ClusterNotSetReply(botCtx, response)
				return
			}
			text := fmt.Sprintf("current cluster id is %d", clusterID)
			logrus.Error(response.Reply(text, util.ReplyOpt(botCtx)))
		},
	}
	bot.Command("c {clusterID}", clusterDefinition)

	// command pr2c
	pr2cDefinition := &slacker.CommandDefinition{
		Description:       "Create a Harvester cluster after merging PRs or checkout branches, always build ISO",
		Examples:          []string{"pr2c 0 0"},
		AuthorizationFunc: authorizationFunc,
		Handler: func(botCtx slacker.BotContext, request slacker.Request, response slacker.ResponseWriter) {
			userID, _ := getUserIDByUserName(botCtx.Event().UserName)
			userContext := getUserContext(userID)
			clusterID := userContext.GetClusterID()
			if clusterID == 0 {
				util.ClusterNotSetReply(botCtx, response)
				return
			}
			harvesterPRs := request.StringParam("harvesterPRs", "0")
			harvesterInstallerPRs := request.StringParam("harvesterInstallerPRs", "0")
			harvesterConfigURL := request.StringParam("harvesterConfigURL", "")
			bashCommand := fmt.Sprintf("./pr2c.sh %d %d %s %s %s %t", userID, clusterID, harvesterPRs, harvesterInstallerPRs, harvesterConfigURL, false)
			util.Shell2Reply(botCtx, response, bashCommand)
		},
	}
	bot.Command("pr2c {harvesterPRs} {harvesterInstallerPRs} {harvesterConfigURL}", pr2cDefinition)

	// command pr2cNoBuild
	pr2cNoBuildDefinition := &slacker.CommandDefinition{
		Description:       "Create a Harvester cluster based on PRs or branches, but use the built ISO from pr2c",
		Examples:          []string{"pr2cNoBuild 0 0"},
		AuthorizationFunc: authorizationFunc,
		Handler: func(botCtx slacker.BotContext, request slacker.Request, response slacker.ResponseWriter) {
			userID, _ := getUserIDByUserName(botCtx.Event().UserName)
			userContext := getUserContext(userID)
			clusterID := userContext.GetClusterID()
			if clusterID == 0 {
				util.ClusterNotSetReply(botCtx, response)
				return
			}
			harvesterPRs := request.StringParam("harvesterPRs", "0")
			harvesterInstallerPRs := request.StringParam("harvesterInstallerPRs", "0")
			harvesterConfigURL := request.StringParam("harvesterConfigURL", "")
			bashCommand := fmt.Sprintf("./pr2c.sh %d %d %s %s %s %t", userID, clusterID, harvesterPRs, harvesterInstallerPRs, harvesterConfigURL, true)
			util.Shell2Reply(botCtx, response, bashCommand)
		},
	}
	bot.Command("pr2cNoBuild {harvesterPRs} {harvesterInstallerPRs} {harvesterConfigURL}", pr2cNoBuildDefinition)

	// command v2c
	v2cDefinition := &slacker.CommandDefinition{
		Description:       "Create a Harvester cluster after downloading the ISO",
		Examples:          []string{"v2c v1.1"},
		AuthorizationFunc: authorizationFunc,
		Handler: func(botCtx slacker.BotContext, request slacker.Request, response slacker.ResponseWriter) {
			userID, _ := getUserIDByUserName(botCtx.Event().UserName)
			userContext := getUserContext(userID)
			clusterID := userContext.GetClusterID()
			if clusterID == 0 {
				util.ClusterNotSetReply(botCtx, response)
				return
			}
			harvesterVersion := request.StringParam("harvesterVersion", "0")
			harvesterConfigURL := request.StringParam("harvesterConfigURL", "")
			bashCommand := fmt.Sprintf("./v2c.sh %d %d %s %s", userID, clusterID, harvesterVersion, harvesterConfigURL)
			util.Shell2Reply(botCtx, response, bashCommand)
		},
	}
	bot.Command("v2c {harvesterVersion} {harvesterConfigURL}", v2cDefinition)

	// command log
	logDefinition := &slacker.CommandDefinition{
		Description:       "Tail Harvester cluster logs",
		Examples:          []string{"log", "log 100"},
		AuthorizationFunc: authorizationFunc,
		Handler: func(botCtx slacker.BotContext, request slacker.Request, response slacker.ResponseWriter) {
			userID, _ := getUserIDByUserName(botCtx.Event().UserName)
			userContext := getUserContext(userID)
			clusterID := userContext.GetClusterID()
			if clusterID == 0 {
				util.ClusterNotSetReply(botCtx, response)
				return
			}
			lineNumber := request.IntegerParam("lineNumber", 20)
			bashCommand := fmt.Sprintf("./log.sh %d %d %d", userID, clusterID, lineNumber)
			util.Shell2Reply(botCtx, response, bashCommand)
		},
	}
	bot.Command("log {lineNumber}", logDefinition)

	// command url
	urlDefinition := &slacker.CommandDefinition{
		Description:       "Show Harvester cluster URLs",
		Examples:          []string{"url"},
		AuthorizationFunc: authorizationFunc,
		Handler: func(botCtx slacker.BotContext, request slacker.Request, response slacker.ResponseWriter) {
			userID, _ := getUserIDByUserName(botCtx.Event().UserName)
			userContext := getUserContext(userID)
			clusterID := userContext.GetClusterID()
			if clusterID == 0 {
				util.ClusterNotSetReply(botCtx, response)
				return
			}
			bashCommand := fmt.Sprintf("./url.sh %d %d", userID, clusterID)
			util.Shell2Reply(botCtx, response, bashCommand)
		},
	}
	bot.Command("url", urlDefinition)

	// command version
	versionDefinition := &slacker.CommandDefinition{
		Description:       "Show Harvester version",
		Examples:          []string{"version"},
		AuthorizationFunc: authorizationFunc,
		Handler: func(botCtx slacker.BotContext, request slacker.Request, response slacker.ResponseWriter) {
			userID, _ := getUserIDByUserName(botCtx.Event().UserName)
			userContext := getUserContext(userID)
			clusterID := userContext.GetClusterID()
			if clusterID == 0 {
				util.ClusterNotSetReply(botCtx, response)
				return
			}
			bashCommand := fmt.Sprintf("./version.sh %d %d", userID, clusterID)
			util.Shell2Reply(botCtx, response, bashCommand)
		},
	}
	bot.Command("version", versionDefinition)

	// command settings
	settingsDefinition := &slacker.CommandDefinition{
		Description:       "Show Harvester settings",
		Examples:          []string{"settings"},
		AuthorizationFunc: authorizationFunc,
		Handler: func(botCtx slacker.BotContext, request slacker.Request, response slacker.ResponseWriter) {
			userID, _ := getUserIDByUserName(botCtx.Event().UserName)
			userContext := getUserContext(userID)
			clusterID := userContext.GetClusterID()
			if clusterID == 0 {
				util.ClusterNotSetReply(botCtx, response)
				return
			}
			bashCommand := fmt.Sprintf("./settings.sh %d %d", userID, clusterID)
			util.Shell2Reply(botCtx, response, bashCommand)
		},
	}
	bot.Command("settings", settingsDefinition)

	// command kubeconfig
	kubeconfigDefinition := &slacker.CommandDefinition{
		Description:       "Show Harvester cluster kubeconfig content",
		Examples:          []string{"kubeconfig"},
		AuthorizationFunc: authorizationFunc,
		Handler: func(botCtx slacker.BotContext, request slacker.Request, response slacker.ResponseWriter) {
			userID, _ := getUserIDByUserName(botCtx.Event().UserName)
			userContext := getUserContext(userID)
			clusterID := userContext.GetClusterID()
			if clusterID == 0 {
				util.ClusterNotSetReply(botCtx, response)
				return
			}
			bashCommand := fmt.Sprintf("./kubeconfig.sh %d %d", userID, clusterID)
			util.Shell2Reply(botCtx, response, bashCommand)
		},
	}
	bot.Command("kubeconfig", kubeconfigDefinition)

	// command sshconfig
	sshconfigDefinition := &slacker.CommandDefinition{
		Description:       "Show ssh config for connecting",
		Examples:          []string{"sshconfig"},
		AuthorizationFunc: authorizationFunc,
		Handler: func(botCtx slacker.BotContext, request slacker.Request, response slacker.ResponseWriter) {
			userID, _ := getUserIDByUserName(botCtx.Event().UserName)
			userContext := getUserContext(userID)
			clusterID := userContext.GetClusterID()
			if clusterID == 0 {
				util.ClusterNotSetReply(botCtx, response)
				return
			}
			bashCommand := fmt.Sprintf("./sshconfig.sh %d %d", userID, clusterID)
			util.Shell2Reply(botCtx, response, bashCommand)
		},
	}
	bot.Command("sshconfig", sshconfigDefinition)

	// command destroy
	destroyDefinition := &slacker.CommandDefinition{
		Description:       "Destroy Harvester cluster nodes",
		Examples:          []string{"destroy"},
		AuthorizationFunc: authorizationFunc,
		Handler: func(botCtx slacker.BotContext, request slacker.Request, response slacker.ResponseWriter) {
			userID, _ := getUserIDByUserName(botCtx.Event().UserName)
			userContext := getUserContext(userID)
			clusterID := userContext.GetClusterID()
			if clusterID == 0 {
				util.ClusterNotSetReply(botCtx, response)
				return
			}
			bashCommand := fmt.Sprintf("./destroy.sh %d %d", userID, clusterID)
			util.Shell2Reply(botCtx, response, bashCommand)
		},
	}
	bot.Command("destroy", destroyDefinition)

	// command history
	historyDefinition := &slacker.CommandDefinition{
		Description:       "Show history",
		Examples:          []string{"history", "history 10"},
		AuthorizationFunc: authorizationFunc,
		Handler: func(botCtx slacker.BotContext, request slacker.Request, response slacker.ResponseWriter) {
			userID, _ := getUserIDByUserName(botCtx.Event().UserName)
			userContext := getUserContext(userID)
			historyNumber := request.IntegerParam("historyNumber", 20)
			historyLen := len(userContext.History)
			var text string
			if historyLen > historyNumber {
				text = strings.Join(userContext.History[historyLen-historyNumber:], "\n")
			} else {
				if historyLen == 0 {
					text = "N/A"
				} else {
					text = strings.Join(userContext.History, "\n")
				}
			}
			logrus.Error(response.Reply(text, util.ReplyOpt(botCtx)))
		},
	}
	bot.Command("history {historyNumber}", historyDefinition)

	// command virsh
	virshDefinition := &slacker.CommandDefinition{
		Description:       "virsh command warpper",
		Examples:          []string{"virsh list"},
		AuthorizationFunc: authorizationFunc,
		Handler: func(botCtx slacker.BotContext, request slacker.Request, response slacker.ResponseWriter) {
			command := request.StringParam("command", "")
			args := request.StringParam("args", "")
			bashCommand := fmt.Sprintf("./virsh.sh %s %s", command, args)
			util.Shell2Reply(botCtx, response, bashCommand)
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
			util.Shell2Reply(botCtx, response, bashCommand)
		},
	}
	bot.Command("ps", psDefinition)

	// command pr2ui
	pr2uiDefinition := &slacker.CommandDefinition{
		Description:       "Build Harvester Dashboard",
		Examples:          []string{"pr2ui 0"},
		AuthorizationFunc: authorizationFunc,
		Handler: func(botCtx slacker.BotContext, request slacker.Request, response slacker.ResponseWriter) {
			userID, _ := getUserIDByUserName(botCtx.Event().UserName)
			uiPRs := request.StringParam("uiPRs", "0")
			bashCommand := fmt.Sprintf("./pr2ui.sh %d %s", userID, uiPRs)
			util.Shell2Reply(botCtx, response, bashCommand)
		},
	}
	bot.Command("pr2ui {uiPRs}", pr2uiDefinition)

	// command log4ui
	log4uiDefinition := &slacker.CommandDefinition{
		Description:       "Tail Harvester Dashboard Build Logs",
		Examples:          []string{"log4ui", "log4ui 100"},
		AuthorizationFunc: authorizationFunc,
		Handler: func(botCtx slacker.BotContext, request slacker.Request, response slacker.ResponseWriter) {
			userID, _ := getUserIDByUserName(botCtx.Event().UserName)
			lineNumber := request.IntegerParam("lineNumber", 20)
			bashCommand := fmt.Sprintf("./log4ui.sh %d %d", userID, lineNumber)
			util.Shell2Reply(botCtx, response, bashCommand)
		},
	}
	bot.Command("log4ui {lineNumber}", log4uiDefinition)

	// bot run
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	err := bot.Listen(ctx)
	if err != nil {
		log.Fatal(err)
	}
}
