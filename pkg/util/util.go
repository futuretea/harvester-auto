package util

import (
	"errors"
	"os"
	"os/exec"
	"strings"

	"github.com/shomali11/slacker"
	"github.com/sirupsen/logrus"

	"github.com/futuretea/harvester-auto/pkg/constants"
)

var (
	shellBlackList = []string{
		"..",
		"&",
		";",
	}
)

func ReplyOpt(botCtx slacker.BotContext) slacker.ReplyOption {
	return slacker.WithThreadReply(botCtx.Event().Type != constants.EventTypeMessage)
}

func ReplyErrorOpt(botCtx slacker.BotContext) slacker.ReportErrorOption {
	return slacker.WithThreadError(botCtx.Event().Type != constants.EventTypeMessage)
}

func shellCheck(bashCommand string) bool {
	for _, s := range shellBlackList {
		if strings.Contains(bashCommand, s) {
			return false
		}
	}
	return true
}

func ClusterNotSetReply(botCtx slacker.BotContext, response slacker.ResponseWriter) {
	err := errors.New("the current cluster id is not set, run the `cluster {clusterID}` command to set the current cluster id ")
	response.ReportError(err, ReplyErrorOpt(botCtx))
}

func Shell2Reply(botCtx slacker.BotContext, response slacker.ResponseWriter, bashCommand string) {
	useThread := botCtx.Event().Type != constants.EventTypeMessage
	logrus.Debugln(bashCommand)
	if !shellCheck(bashCommand) {
		err := errors.New("unknown command")
		logrus.Error(err)
		response.ReportError(err, slacker.WithThreadError(useThread))
		return
	}

	cmd := exec.Command("/usr/bin/bash", strings.Split(bashCommand, " ")...)
	cmd.Env = os.Environ()
	cmd.Dir = constants.CommandsDir
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
