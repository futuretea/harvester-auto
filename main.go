package main

import (
	"context"
	"errors"
	"fmt"
	"log"
	"os"
	"strings"

	"github.com/fsnotify/fsnotify"
	"github.com/shomali11/slacker"
	"github.com/sirupsen/logrus"
	"github.com/spf13/viper"

	"github.com/futuretea/harvester-auto/pkg/config"
	"github.com/futuretea/harvester-auto/pkg/constants"
	"github.com/futuretea/harvester-auto/pkg/ctx"
	"github.com/futuretea/harvester-auto/pkg/util"
)

var (
	conf         config.Config
	userContexts = map[string]*ctx.Context{}
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
	go dynamicConfig()

	// log
	logrus.SetFormatter(&logrus.JSONFormatter{})
	logrus.SetLevel(logrus.WarnLevel)
	// env
	for envName, envValue := range conf.Slack.Envs {
		os.Setenv(envName, envValue)
	}
}

func dynamicConfig() {
	viper.WatchConfig()
	viper.OnConfigChange(func(e fsnotify.Event) {
		if err := viper.Unmarshal(&conf); err != nil {
			panic(fmt.Errorf("unable to decode into struct, %w", err))
		}
	})
}

func getUserContext(userName string) *ctx.Context {
	return userContexts[userName]
}

func setUserContext(userName string, userContext *ctx.Context) {
	userContexts[userName] = userContext
}

func getUserByUserName(userName string) (*config.User, bool) {
	user, exist := conf.Slack.Users[userName]
	return user, exist
}

func main() {
	// new bot
	bot := slacker.NewClient(conf.Slack.BotToken, conf.Slack.AppToken)
	authorizationFunc := func(botCtx slacker.BotContext, request slacker.Request) bool {
		userName := botCtx.Event().UserName
		text := botCtx.Event().Text
		_, exist := getUserByUserName(userName)
		if !exist {
			logrus.Infof("unknown user: %s", userName)
			return false
		}
		userContext := getUserContext(userName)
		if userContext == nil {
			userContext = ctx.CreateContext(0, text)
			setUserContext(userName, userContext)
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

	// command l
	lDefinition := &slacker.CommandDefinition{
		Description:       "List Harvester clusters",
		Examples:          []string{"l"},
		AuthorizationFunc: authorizationFunc,
		Handler: func(botCtx slacker.BotContext, request slacker.Request, response slacker.ResponseWriter) {
			user, _ := getUserByUserName(botCtx.Event().UserName)
			bashCommand := fmt.Sprintf("./l.sh %d", user.NamespaceID)
			util.Shell2Reply(botCtx, response, bashCommand)
		},
	}
	bot.Command("l", lDefinition)

	// command c
	clusterDefinition := &slacker.CommandDefinition{
		Description:       "Show/Set Current Harvester cluster",
		Examples:          []string{"c (show current cluster id)", "c 1 (set current cluster id to 1)"},
		AuthorizationFunc: authorizationFunc,
		Handler: func(botCtx slacker.BotContext, request slacker.Request, response slacker.ResponseWriter) {
			userName := botCtx.Event().UserName
			userContext := getUserContext(userName)
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
			userName := botCtx.Event().UserName
			user, _ := getUserByUserName(userName)
			userContext := getUserContext(userName)
			namespaceID := user.NamespaceID
			if user.Mode != config.ModeRW {
				util.NoPermissionReply(botCtx, response)
				return
			}
			clusterID := userContext.GetClusterID()
			if clusterID == 0 {
				util.ClusterNotSetReply(botCtx, response)
				return
			}
			harvesterPRs := request.StringParam("harvesterPRs", "0")
			harvesterInstallerPRs := request.StringParam("harvesterInstallerPRs", "0")
			harvesterConfigURL := request.StringParam("harvesterConfigURL", "")
			bashCommand := fmt.Sprintf("./pr2c.sh %d %d %s %s %s %t", namespaceID, clusterID, harvesterPRs, harvesterInstallerPRs, harvesterConfigURL, false)
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
			userName := botCtx.Event().UserName
			user, _ := getUserByUserName(userName)
			userContext := getUserContext(userName)
			namespaceID := user.NamespaceID
			if user.Mode != config.ModeRW {
				util.NoPermissionReply(botCtx, response)
				return
			}
			clusterID := userContext.GetClusterID()
			if clusterID == 0 {
				util.ClusterNotSetReply(botCtx, response)
				return
			}
			harvesterPRs := request.StringParam("harvesterPRs", "0")
			harvesterInstallerPRs := request.StringParam("harvesterInstallerPRs", "0")
			harvesterConfigURL := request.StringParam("harvesterConfigURL", "")
			bashCommand := fmt.Sprintf("./pr2c.sh %d %d %s %s %s %t", namespaceID, clusterID, harvesterPRs, harvesterInstallerPRs, harvesterConfigURL, true)
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
			userName := botCtx.Event().UserName
			user, _ := getUserByUserName(userName)
			userContext := getUserContext(userName)
			namespaceID := user.NamespaceID
			if user.Mode != config.ModeRW {
				util.NoPermissionReply(botCtx, response)
				return
			}
			clusterID := userContext.GetClusterID()
			if clusterID == 0 {
				util.ClusterNotSetReply(botCtx, response)
				return
			}
			harvesterVersion := request.StringParam("harvesterVersion", "0")
			harvesterConfigURL := request.StringParam("harvesterConfigURL", "")
			bashCommand := fmt.Sprintf("./v2c.sh %d %d %s %s", namespaceID, clusterID, harvesterVersion, harvesterConfigURL)
			util.Shell2Reply(botCtx, response, bashCommand)
		},
	}
	bot.Command("v2c {harvesterVersion} {harvesterConfigURL}", v2cDefinition)

	// command log
	log4cDefinition := &slacker.CommandDefinition{
		Description:       "Tail Harvester cluster logs",
		Examples:          []string{"log4c", "log4c 100"},
		AuthorizationFunc: authorizationFunc,
		Handler: func(botCtx slacker.BotContext, request slacker.Request, response slacker.ResponseWriter) {
			userName := botCtx.Event().UserName
			user, _ := getUserByUserName(userName)
			userContext := getUserContext(userName)
			namespaceID := user.NamespaceID
			clusterID := userContext.GetClusterID()
			if clusterID == 0 {
				util.ClusterNotSetReply(botCtx, response)
				return
			}
			lineNumber := request.IntegerParam("lineNumber", 20)
			bashCommand := fmt.Sprintf("./log4c.sh %d %d %d", namespaceID, clusterID, lineNumber)
			util.Shell2Reply(botCtx, response, bashCommand)
		},
	}
	bot.Command("log4c {lineNumber}", log4cDefinition)

	// command url
	urlDefinition := &slacker.CommandDefinition{
		Description:       "Show Harvester cluster URLs",
		Examples:          []string{"url"},
		AuthorizationFunc: authorizationFunc,
		Handler: func(botCtx slacker.BotContext, request slacker.Request, response slacker.ResponseWriter) {
			userName := botCtx.Event().UserName
			user, _ := getUserByUserName(userName)
			userContext := getUserContext(userName)
			namespaceID := user.NamespaceID
			clusterID := userContext.GetClusterID()
			if clusterID == 0 {
				util.ClusterNotSetReply(botCtx, response)
				return
			}
			bashCommand := fmt.Sprintf("./url.sh %d %d", namespaceID, clusterID)
			util.Shell2Reply(botCtx, response, bashCommand)
		},
	}
	bot.Command("url", urlDefinition)

	// command status
	statusDefinition := &slacker.CommandDefinition{
		Description:       "Show Harvester cluster Status",
		Examples:          []string{"status"},
		AuthorizationFunc: authorizationFunc,
		Handler: func(botCtx slacker.BotContext, request slacker.Request, response slacker.ResponseWriter) {
			userName := botCtx.Event().UserName
			user, _ := getUserByUserName(userName)
			userContext := getUserContext(userName)
			namespaceID := user.NamespaceID
			clusterID := userContext.GetClusterID()
			if clusterID == 0 {
				util.ClusterNotSetReply(botCtx, response)
				return
			}
			bashCommand := fmt.Sprintf("./status.sh %d %d", namespaceID, clusterID)
			util.Shell2Reply(botCtx, response, bashCommand)
		},
	}
	bot.Command("status", statusDefinition)

	// command version
	versionDefinition := &slacker.CommandDefinition{
		Description:       "Show Harvester version",
		Examples:          []string{"version"},
		AuthorizationFunc: authorizationFunc,
		Handler: func(botCtx slacker.BotContext, request slacker.Request, response slacker.ResponseWriter) {
			userName := botCtx.Event().UserName
			user, _ := getUserByUserName(userName)
			userContext := getUserContext(userName)
			namespaceID := user.NamespaceID
			clusterID := userContext.GetClusterID()
			if clusterID == 0 {
				util.ClusterNotSetReply(botCtx, response)
				return
			}
			bashCommand := fmt.Sprintf("./version.sh %d %d", namespaceID, clusterID)
			util.Shell2Reply(botCtx, response, bashCommand)
		},
	}
	bot.Command("version", versionDefinition)

	// command name
	nameDefinition := &slacker.CommandDefinition{
		Description:       "Show/Set Harvester name",
		Examples:          []string{"name"},
		AuthorizationFunc: authorizationFunc,
		Handler: func(botCtx slacker.BotContext, request slacker.Request, response slacker.ResponseWriter) {
			name := request.StringParam("name", "")
			userName := botCtx.Event().UserName
			user, _ := getUserByUserName(userName)
			userContext := getUserContext(userName)
			namespaceID := user.NamespaceID
			clusterID := userContext.GetClusterID()
			if clusterID == 0 {
				util.ClusterNotSetReply(botCtx, response)
				return
			}
			bashCommand := fmt.Sprintf("./name.sh %d %d %s", namespaceID, clusterID, name)
			util.Shell2Reply(botCtx, response, bashCommand)
		},
	}
	bot.Command("name {name}", nameDefinition)

	// command settings
	settingsDefinition := &slacker.CommandDefinition{
		Description:       "Show Harvester settings",
		Examples:          []string{"settings"},
		AuthorizationFunc: authorizationFunc,
		Handler: func(botCtx slacker.BotContext, request slacker.Request, response slacker.ResponseWriter) {
			userName := botCtx.Event().UserName
			user, _ := getUserByUserName(userName)
			userContext := getUserContext(userName)
			namespaceID := user.NamespaceID
			clusterID := userContext.GetClusterID()
			if clusterID == 0 {
				util.ClusterNotSetReply(botCtx, response)
				return
			}
			bashCommand := fmt.Sprintf("./settings.sh %d %d", namespaceID, clusterID)
			util.Shell2Reply(botCtx, response, bashCommand)
		},
	}
	bot.Command("settings", settingsDefinition)

	// command podImages
	pisDefinition := &slacker.CommandDefinition{
		Description:       "Show Pod Images",
		Examples:          []string{"pis"},
		AuthorizationFunc: authorizationFunc,
		Handler: func(botCtx slacker.BotContext, request slacker.Request, response slacker.ResponseWriter) {
			kubeNamespace := request.StringParam("namespace", "harvester-system")
			userName := botCtx.Event().UserName
			user, _ := getUserByUserName(userName)
			userContext := getUserContext(userName)
			namespaceID := user.NamespaceID
			clusterID := userContext.GetClusterID()
			if clusterID == 0 {
				util.ClusterNotSetReply(botCtx, response)
				return
			}
			bashCommand := fmt.Sprintf("./pis.sh %d %d %s", namespaceID, clusterID, kubeNamespace)
			util.Shell2Reply(botCtx, response, bashCommand)
		},
	}
	bot.Command("pis {namespace}", pisDefinition)

	// command get
	getDefinition := &slacker.CommandDefinition{
		Description:       "kubectl get",
		Examples:          []string{"get"},
		AuthorizationFunc: authorizationFunc,
		Handler: func(botCtx slacker.BotContext, request slacker.Request, response slacker.ResponseWriter) {
			args := request.StringParam("args", "vm -n default -o wide")
			userName := botCtx.Event().UserName
			user, _ := getUserByUserName(userName)
			userContext := getUserContext(userName)
			namespaceID := user.NamespaceID
			clusterID := userContext.GetClusterID()
			if clusterID == 0 {
				util.ClusterNotSetReply(botCtx, response)
				return
			}
			bashCommand := fmt.Sprintf("./get.sh %d %d %s", namespaceID, clusterID, args)
			util.Shell2Reply(botCtx, response, bashCommand)
		},
	}
	bot.Command("get {args}", getDefinition)

	// command kubeconfig
	kubeconfigDefinition := &slacker.CommandDefinition{
		Description:       "Show Harvester cluster kubeconfig content",
		Examples:          []string{"kubeconfig"},
		AuthorizationFunc: authorizationFunc,
		Handler: func(botCtx slacker.BotContext, request slacker.Request, response slacker.ResponseWriter) {
			userName := botCtx.Event().UserName
			user, _ := getUserByUserName(userName)
			userContext := getUserContext(userName)
			namespaceID := user.NamespaceID
			clusterID := userContext.GetClusterID()
			if clusterID == 0 {
				util.ClusterNotSetReply(botCtx, response)
				return
			}
			bashCommand := fmt.Sprintf("./kubeconfig.sh %d %d", namespaceID, clusterID)
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
			userName := botCtx.Event().UserName
			user, _ := getUserByUserName(userName)
			userContext := getUserContext(userName)
			namespaceID := user.NamespaceID
			clusterID := userContext.GetClusterID()
			if clusterID == 0 {
				util.ClusterNotSetReply(botCtx, response)
				return
			}
			bashCommand := fmt.Sprintf("./sshconfig.sh %d %d", namespaceID, clusterID)
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
			userName := botCtx.Event().UserName
			user, _ := getUserByUserName(userName)
			userContext := getUserContext(userName)
			namespaceID := user.NamespaceID
			if user.Mode != config.ModeRW {
				util.NoPermissionReply(botCtx, response)
				return
			}
			clusterID := userContext.GetClusterID()
			if clusterID == 0 {
				util.ClusterNotSetReply(botCtx, response)
				return
			}
			bashCommand := fmt.Sprintf("./destroy.sh %d %d", namespaceID, clusterID)
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
			userName := botCtx.Event().UserName
			userContext := getUserContext(userName)
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
		Description:       "Show running jobs",
		Examples:          []string{"ps"},
		AuthorizationFunc: authorizationFunc,
		Handler: func(botCtx slacker.BotContext, request slacker.Request, response slacker.ResponseWriter) {
			userName := botCtx.Event().UserName
			user, _ := getUserByUserName(userName)
			userContext := getUserContext(userName)
			namespaceID := user.NamespaceID
			clusterID := userContext.GetClusterID()
			bashCommand := fmt.Sprintf("./ps.sh %d %d", namespaceID, clusterID)
			util.Shell2Reply(botCtx, response, bashCommand)
		},
	}
	bot.Command("ps", psDefinition)

	// command kill
	killDefinition := &slacker.CommandDefinition{
		Description:       "Kill running job",
		Examples:          []string{"kill 2c", "kill 2pt", "kill 2ui"},
		AuthorizationFunc: authorizationFunc,
		Handler: func(botCtx slacker.BotContext, request slacker.Request, response slacker.ResponseWriter) {
			userName := botCtx.Event().UserName
			user, _ := getUserByUserName(userName)
			userContext := getUserContext(userName)
			namespaceID := user.NamespaceID
			if user.Mode != config.ModeRW {
				util.NoPermissionReply(botCtx, response)
				return
			}
			clusterID := userContext.GetClusterID()
			job := request.StringParam("job", "")
			switch job {
			case "2c", "2pt":
				if clusterID == 0 {
					util.ClusterNotSetReply(botCtx, response)
					return
				}
			case "2ui":
			case "":
				response.ReportError(errors.New("missing job type"), util.ReplyErrorOpt(botCtx))
				return
			default:
				response.ReportError(errors.New("invalid job type"), util.ReplyErrorOpt(botCtx))
				return
			}
			bashCommand := fmt.Sprintf("./kill.sh %d %d %s", namespaceID, clusterID, job)
			util.Shell2Reply(botCtx, response, bashCommand)
		},
	}
	bot.Command("kill {job}", killDefinition)

	// command pr2pt
	pr2ptDefinition := &slacker.CommandDefinition{
		Description:       "Patch Harvester image after merging PRs or checkout branches, always build image",
		Examples:          []string{"pr2pt harvester 0"},
		AuthorizationFunc: authorizationFunc,
		Handler: func(botCtx slacker.BotContext, request slacker.Request, response slacker.ResponseWriter) {
			userName := botCtx.Event().UserName
			user, _ := getUserByUserName(userName)
			userContext := getUserContext(userName)
			namespaceID := user.NamespaceID
			if user.Mode != config.ModeRW {
				util.NoPermissionReply(botCtx, response)
				return
			}
			clusterID := userContext.GetClusterID()
			if clusterID == 0 {
				util.ClusterNotSetReply(botCtx, response)
				return
			}
			repoName := request.StringParam("repoName", "harvester")
			repoPRs := request.StringParam("repoPRs", "0")
			bashCommand := fmt.Sprintf("./pr2pt.sh %d %d %s %s", namespaceID, clusterID, repoName, repoPRs)
			util.Shell2Reply(botCtx, response, bashCommand)
		},
	}
	bot.Command("pr2pt {repoName} {repoPRs}", pr2ptDefinition)

	// command log4pt
	log4ptDefinition := &slacker.CommandDefinition{
		Description:       "Tail Harvester Patch Logs",
		Examples:          []string{"log4pt", "log4pt 100"},
		AuthorizationFunc: authorizationFunc,
		Handler: func(botCtx slacker.BotContext, request slacker.Request, response slacker.ResponseWriter) {
			userName := botCtx.Event().UserName
			user, _ := getUserByUserName(userName)
			userContext := getUserContext(userName)
			namespaceID := user.NamespaceID
			clusterID := userContext.GetClusterID()
			if clusterID == 0 {
				util.ClusterNotSetReply(botCtx, response)
				return
			}
			lineNumber := request.IntegerParam("lineNumber", 20)
			bashCommand := fmt.Sprintf("./log4pt.sh %d %d %d", namespaceID, clusterID, lineNumber)
			util.Shell2Reply(botCtx, response, bashCommand)
		},
	}
	bot.Command("log4pt {lineNumber}", log4ptDefinition)

	// command pr2ui
	pr2uiDefinition := &slacker.CommandDefinition{
		Description:       "Build Harvester Dashboard",
		Examples:          []string{"pr2ui 0"},
		AuthorizationFunc: authorizationFunc,
		Handler: func(botCtx slacker.BotContext, request slacker.Request, response slacker.ResponseWriter) {
			userName := botCtx.Event().UserName
			user, _ := getUserByUserName(userName)
			namespaceID := user.NamespaceID
			uiPRs := request.StringParam("uiPRs", "0")
			bashCommand := fmt.Sprintf("./pr2ui.sh %d %s", namespaceID, uiPRs)
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
			userName := botCtx.Event().UserName
			user, _ := getUserByUserName(userName)
			namespaceID := user.NamespaceID
			lineNumber := request.IntegerParam("lineNumber", 20)
			bashCommand := fmt.Sprintf("./log4ui.sh %d %d", namespaceID, lineNumber)
			util.Shell2Reply(botCtx, response, bashCommand)
		},
	}
	bot.Command("log4ui {lineNumber}", log4uiDefinition)

	// bot run
	c, cancel := context.WithCancel(context.Background())
	defer cancel()

	err := bot.Listen(c)
	if err != nil {
		log.Fatal(err)
	}
}
