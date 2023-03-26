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
	bot.Command("history", historyDefinition)

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

	// command cluster
	clusterDefinition := &slacker.CommandDefinition{
		Description:       "Show/Set Current Harvester cluster",
		Examples:          []string{"cluster (show current cluster id)", "cluster 1 (set current cluster id to 1)"},
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
	bot.Command("cluster {clusterID}", clusterDefinition)

	// command pr2c
	pr2cDefinition := &slacker.CommandDefinition{
		Description:       "Create Harvester cluster after merge PR",
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
			bashCommand := fmt.Sprintf("./pr2c.sh %d %d %s %s %s", userID, clusterID, harvesterPRs, harvesterInstallerPRs, harvesterConfigURL)
			util.Shell2Reply(botCtx, response, bashCommand)
		},
	}
	bot.Command("pr2c {harvesterPRs} {harvesterInstallerPRs} {harvesterConfigURL}", pr2cDefinition)

	// command v2c
	v2cDefinition := &slacker.CommandDefinition{
		Description:       "Create Harvester cluster after download ISO",
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

	// command url
	urlDefinition := &slacker.CommandDefinition{
		Description:       "Show Harvester cluster url",
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

	// command tail
	tailDefinition := &slacker.CommandDefinition{
		Description:       "Tail Harvester cluster logs",
		Examples:          []string{"tail", "tail 100"},
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
			bashCommand := fmt.Sprintf("./tail.sh %d %d %d", userID, clusterID, lineNumber)
			util.Shell2Reply(botCtx, response, bashCommand)
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

	// bot run
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	err := bot.Listen(ctx)
	if err != nil {
		log.Fatal(err)
	}
}
