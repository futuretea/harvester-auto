package user

type Context struct {
	ClusterID uint8
	History   []string
}

func (c *Context) GetClusterID() uint8 {
	return c.ClusterID
}

func (c *Context) SetClusterID(clusterID uint8) {
	c.ClusterID = clusterID
}

func (c *Context) Record(text string) {
	c.History = append(c.History, text)
}

func CreateContext(clusterID uint8, text string) *Context {
	return &Context{
		ClusterID: clusterID,
		History:   []string{text},
	}
}
