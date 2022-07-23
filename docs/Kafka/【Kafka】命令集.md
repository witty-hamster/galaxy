[TOC]



> 未配置环境变量时，需要在 Kafka的安装目录下进行操作

# Kafka 启停命令

## 启动 Kafka

- 前台启动

  ```sh
  $ bin/kafka-server-start.sh config/server.properties
  ```

- 后台启动

  ```sh
  $ bin/kafka-server-start.sh config/server.properties &
  ```

## 停止 Kafka

- 命令方式

  ```sh
  $ bin/kafka-server-stop.sh
  ```

- 直接杀死方式

  ```sh
  # 方式一：通过 ps + 管道方式，找到Kafka对应的端口号，直接使用 kill 命令杀死
  $ ps -ef | grep kafka
  $ kill -9 <kafka的端口号>
  
  # 方式二：通过 java 的 jps 方式，找到Kafka对应的端口号，直接使用 kill 命令杀死
  $ jps
  $ kill -9 <kafka的端口号>
  ```

# 控制台操作 `kafka-topic`

> 主题相关命令行操作

## 创建主题 - 简单方式

```sh
$ bin/kafka-topics --create --bootstrap-server localhost:9092 --replication-factor 1 --partitions 1 --topic test
```

- `--create`：表示创建一个主题 <必填>
- `--bootstrap-server`：表示Kafka服务端连接IP:PORT <必填>
  - 旧版本Kafka在创建主题时，使用的是 `--zookeeper`
- `--replication-factor`：每个分区的副本个数。如果未提供，则使用集群默认值
- `--partitions`：主题分区数（警告：如果为具有key的主题增加分区，则分区逻辑或消息顺序将受到影响）。如果未提供，则使用集群默认值
- `--topic`：主题名称。（可接受正则表达式，但仅对更改、描述、删除主题时有效。创建主题时，仅可使用字符串形式）

## 查看主题描述信息

```sh
$ bin/kafka-topics --bootstrap-server localhost:9092 --describe --topic "test"
```

- `--describe`：列出给定主题的详细信息

## 查看所有主题

```sh
$ bin/kafka-topics --bootstrap-server localhost:9092 --list
```

- `--list`：列出所有可用的主题



# 控制台操作 `kafka-console-producer`

> 命令行形式的生成者，可用于测试、调试

## 发送简单消息

```sh
$ bin/kafka-console-producer --bootstrap-server localhost:9092 --topic test
```

- `--bootstrap-server`：指明要连接的Kafka服务器 <必填>
  - 旧版本Kafka中可使用 `--broker-list` 指定集群中服务节点的 IP:PORT，多个节点之间使用逗号分隔
- `--topic`：发送消息到哪个主题



# 控制台操作 `kafka-console-consumer`

> 命令行形式的消费者，可用于测试、调试

## 接收简单消息

```sh
$ bin/kafka-console-consumer --bootstrap-server localhost:9092 --topic test --from-beginning
```

- `--bootstrap-server`：指明要连接的Kafka服务器 <必填>
- `--topic`：指明接收哪个主题的消息
- `--from-beginning`：如果消费者未确定要使用偏移量，将从日志中出现的最早消息开始进行消费
