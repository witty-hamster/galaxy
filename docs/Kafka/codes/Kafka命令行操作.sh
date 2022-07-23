# Kafka命令行操作

## topic 主题操作 -- 命令 bin/kafka-topics.sh
# 查询 -- 查询主题列表
bin/kafka-topics.sh --list --zookeeper <主机名:2181>

# 查询 -- 查询主题的描述信息
bin/kafka-topics.sh --describe --zookeeper <主机名:2181> --topic <主题名称>

# 删除 -- 删除某一个topic主题（注意：这里要在Kafka配置文件中开启删除功能，即`delete.topic.enable=true`，否则仅仅是标记删除）
bin/kafka-topics.sh --delete --zookeeper  <主机名:2181> --topic <主题名称>

# 新增 -- 创建一个新的主题（注意：分区数可以大于集群个数，但是副本数不能大于集群个数。如果副本数大于集群个数，将会报错）
bin/kafka-topics.sh --create --zookeeper  <主机名:2181> --topic <主题名称> --partitions <分区数> --replication-factor <副本数>


# 修改 -- 修改 topic的分区个数
bin/kafka-topics.sh --alter --zookeeper  <主机名:2181> --topic <主题名称> --partitions <分区数>


# 生产者发送消息
bin/kafka-console-producer.sh --broker-list <Kafka主机名称:9092> --topic <主题名称>


# 消费者消费消息
# 从最大偏移量处开始消费，如果之前有消息，不会从头消费
bin/kafka-console-consumer.sh --bootstrap-server <Kafka主机名称:9092> --topic <主机名称> 

# 从头开始消费消息
bin/kafka-console-consumer.sh --bootstrap-server <Kafka主机名称:9092> --topic <主机名称> --from-beginning