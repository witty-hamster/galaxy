[TOC]

---

# Kafka 技术笔记

## 1 - Kafka 概述

### 1.1 定义

​	Kafka 是一个<b style="color:#FF1744">分布式</b>的基于<b style="color:#FF1744">发布/订阅模式</b>的<b style="color:#FF1744">消息队列</b>（Message Queue），主要应用于大数据实时处理领域。

### 1.2 消息队列

#### 1.2.1 传统消息队列的应用场景

![](http://witty-hamster.gitee.io/draw-bed/Kafka/MQ传统应用场景之异步处理.png)

- 使用消息队列的好处
  - **解耦**：
    - 允许你独立的扩展或修改两边的处理过程，只要确保它们遵守同样的接口约束。
  - **可恢复性**：
    - 系统的一部分组件失效时，不会影响到整个系统。消息队列降低了进程间的耦合度，所以即使一个处理消息的进程挂掉，加入队列中的消息仍然可以在系统恢复后被处理。
  - **缓存**：
    - 有助于控制和优化数据流经过系统的速度，解决生产消息和消费消息的处理速度不一致的情况。（一般来说，针对的是生产速度大于消费速度的问题）
  - **灵活性 & 峰值处理能力**：（削峰）
    - 在访问量剧增的情况下，应用仍然需要继续发挥作用，但是这样的突发流量并不常见。如果为以能处理这类峰值访问为标准来投入资源随时待命无疑是巨大的浪费。使用消息队列能够使关键组件顶住突发的访问压力，而不会因为突发的超负荷的请求而完全崩溃。
  - **异步通信**：
    - 很多时候，用户不想也不需要立即处理消息。消息队列提供了异步处理机制，允许用户把一个消息放入队列，但并不立即处理它。想向队列中放入多少消息就放多少，然后在需要的时候再去处理它们。

#### 1.2.2 消息队列的两种模式

- **点对点模式**（<b style="color:#FF1744">一对一</b>，消费者主动拉取数据，消息收到后消息清除）

  消息生产者生产消息发送到 Queue中，然后消息消费者从 Queue中取出并消费消息。消息被消费以后，Queue中不再有存储，所以消息消费者不可能消费到已经被消费的消息。Queue支持存在多个消费者，但是对一个消息而言，只会有一个消费者可以消费。

  ![](http://witty-hamster.gitee.io/draw-bed/Kafka/消息队列模式-点对点模式.png)

- **发布/订阅模式**（<b style="color:#FF1744">一对多</b>，消费者消费数据之后不会清除消息）

  消息生产者（发布）将消息发布到 topic中，同时有多个消息消费者（订阅）消费该消息。和点对点方式不同，发布到 topic的消息会被所有订阅者消费。

  ![](http://witty-hamster.gitee.io/draw-bed/Kafka/消息队列模式-发布订阅模式.png)

  - 发布订阅模式针对消费者来说，有两种获取数据的方式：
    - 方式一：**消费者拉取消息**，此时需要在消费者端开启一个线程，不断地去访问消息队列，判断是否有新消息产生。
    - 方式二：**消息队列推送消息**，这里可能会产生一个问题，当消费者能力不足时，可能会导致消费者端崩溃。

### 1.3 Kafka 基础框架

![](http://witty-hamster.gitee.io/draw-bed/Kafka/Kafka基础框架.png)

- **Producer**：消息生产者，就是想 Kafka broker 发送消息的客户端。
- **Consumer**：消息消费者，向 Kafka broker去消费消息的客户端。
- **Consumer Group（CG）**：消费者组，由多个 consumer组成。<b style="color:#FF1744">消费者组内每个消费者负责消费不同分区的数据，一个分区只能由一个组内消费者消费，消费者组之间互不影响。</b>所有的消费者都属于某个消费者组，即<b style="color:#FF1744">消费者组是逻辑上的一个订阅者</b>。
- **Broker**：一台 Kafka服务器就是一个 broker。一个集群由多个 broker组成。一个 broker可以容纳多个 topic。
- **Topic**：可以理解为一个队列，<b style="color:#FF1744">生产者和消费者面向的都是一个 topic</b>。
- **Partition**：为了实现扩展性，一个非常大的 topic可以分布到多个 broker（即服务器）上，<b style="color:#FF1744">一个 topic可以分为多个 partition</b>，每个 partition是一个有序的队列。
- **Replica**：副本，为保证集群中的某个节点发生故障时，<b style="color:#FF1744">该节点上的 partition数据不丢失，且 Kafka仍然能够继续工作</b>，Kafka提供了副本机制，一个 topic的每个分区都有若干个副本，一个 **leader**和若干个 **follower**。
- **leader**：每个分区多个副本的"主"，生产者发送数据的对象，以及消费者消费数据的对象都是 leader。
- **follower**：每个分区多个副本中的"从"，实时从 leader中同步数据，保持和 leader数据的同步。leader发送故障时，某个 follower会成为新的 leader。

## 2 - Kafka快速入门

### 2.1 安装部署

#### 2.1.1 集群规划

| node01 | node02 | node03 |
| ------ | ------ | ------ |
| ZK     | ZK     | ZK     |
| Kafka  | Kafka  | Kafka  |

#### 2.1.2 Jar包下载

[https://kafka.apache.org/downloads](https://kafka.apache.org/downloads)

#### 2.1.3 集群部署

1. 解压安装包

   ```sh
   [root@node01 software]# tar -zxvf kafka_2.11-0.11.0.0.tgz -C /opt/module
   ```

2. 修改解压后的文件名称

   ```sh
   [root@node01 software]# mv kafka_2.11-0.11.0.0 kafka_2.11
   ```

3. 在`/opt/module/kafka_2.11`目录下创建 logs文件夹

   ```sh
   [root@node01 kafka_2.11]# mkdir logs
   ```

4. 修改配置文件

   ```sh
   [root@node01 kafka_2.11]# cd config/
   [root@node01 config]# vim server.properties
   ```

   配置内容如下：

   ```sh
   # broker 的全局唯一编号，不能重复
   broker.id=0
   # 删除 topic功能使能
   delete.topic.enable=true
   # 处理网络请求的线程数量
   num.network.threads=3
   # 用来处理磁盘IO的线程数量
   num.io.threads=8
   # 发送套接字的缓存区大小
   socket.send.buffer.bytes=102400
   # 接收套接字的缓存区大小
   socket.receive.buffer.bytes=102400
   # 请求套接字的缓冲区大小
   socket.request.max.bytes=104857600
   # Kafka运行日志存放的路径，Kafka暂存数据的目录
   log.dirs=/opt/module/kafka_2.11/logs
   # topic 在当前 broker上的分区个数
   num.partitions=1
   # 用来恢复和清理 data目录下数据的线程数量
   num.recovery.threads.per.data.dir=1
   # segment 文件保留的最长时间，超时将被删除
   log.retention.hours=168
   # 配置连接 Zookeeper集群地址
   zookeeper.connect=node01:2181,node02:2181,node03:2181
   ```

5. 配置环境变量

   ```sh
   [root@node01 kafka_2.11]# vim /etc/profile
   
   # KAFKA_HOME
   export KAFKA_HOME=/opt/module/kafka_2.11
   export PATH=$PATH:$KAFKA_HOME/bin
   
   [root@node01 kafka_2.11]# source /etc/profile
   ```

6. 分发安装包

   ```sh
   [root@node01 module]# xsync kafka_2.11/
   ```

   <b style="color:#FF1744">注意：分发之后，记得配置其他机器的环境变量，并修改配置文件中的 `broker.id`的值</b>

7. 分别在 node02、node03上修改配置文件 `/opt/module/kafka_2.11/config/server.properties`中的 `broker.id = 1`、`broker.id = 2`

   <b style="color:#FF1744">注意：broker.id不能重复。</b>

8. 启动集群

   依次在 node01、node02、node03节点上启动 Kafka

   `bin/kafka-server-start.sh -daemon config/server.properties`

9. 关闭集群

   `bin/kafak-server-stop.sh stop`

10. Kafka群起脚本

    - kafka-start.sh

    ```sh
    #!/bin/bash
    user=`whoami`
    
    for i in node01 node02 node03
    do
    echo "=============== $user@$i ==============="
    ssh $user@$i 'source /etc/profile; /opt/module/kafka_2.11/bin/kafka-server-start.sh -daemon /opt/module/kafka_2.11/config/server.properties'
    done
    ```

    - kafka-stop.sh

    ```sh
    #!/bin/bash
    user=`whoami`
    
    for i in node01 node02 node03
    do
    echo "=============== $user@$i ==============="
    ssh $user@$i 'source /etc/profile; /opt/module/kafka_2.11/bin/kafka-server-stop.sh stop'
    done
    ```

### 2.2 Kafka 命令行操作

#### 2.2.1 Topic主题操作

- 查看当前服务器中的所有 topic

  ```sh
  bin/kafka-topics.sh --list --zookeeper <主机名:2181>
  ```

- 创建 topic

  ```sh
  bin/kafka-topics.sh --create --zookeeper  <主机名:2181> --topic <主题名称> --partitions <分区数> --replication-factor <副本数>
  ```

  - 参数说明：
    - `--topic`：定义 topic名
    - `--replication-factor`：定义副本数
    - `--partitions`：定义分区数

- 删除 topic

  ```sh
  bin/kafka-topics.sh --delete --zookeeper  <主机名:2181> --topic <主题名称>
  ```

  需要在 `server.properties`中设置 `delete.topic.enanle=true`，否则只是标记删除。

- 查看某个 Topic的详情

  ```sh
  bin/kafka-topics.sh --describe --zookeeper <主机名:2181> --topic <主题名称>
  ```

- 修改某个 Topic的分区数

  ```sh
  bin/kafka-topics.sh --alter --zookeeper  <主机名:2181> --topic <主题名称> --partitions <分区数>
  ```

#### 2.2.2 生产者&消费者命令

- 生产者发送消息

  ```sh
  bin/kafka-console-producer.sh --broker-list <Kafka主机名称:9092> --topic <主题名称>
  ```

- 消费者消费消息

  ```sh
  bin/kafka-console-consumer.sh --bootstrap-server <Kafka主机名称:9092> --topic <主机名称> 
  ```

  <b style="color:#FF1744">在命令行中，对于一个已经存在的主题，一个新的消费者不会从头开始消费，会在已消费的最大偏移量位置处开始消费。如果想要实现从头开始消费，可以在命令行中添加参数`--from-beginning`</b>

  ```sh
  bin/kafka-console-consumer.sh --bootstrap-server <Kafka主机名称:9092> --topic <主机名称> --from-beginning
  ```

#### 2.2.3 Kafka数据与日志分离

​	要实现数据与日志的分离，需要在 `server.properties`配置文件中，修改 `log.dir`的值，该键对应的值便是数据存储的路径，但需要注意的是，不能将该路径定义为 kafka安装路径下的 logs目录，因为logs目录是kafka默认存放日志的路径，会自动创建。

​	在ZooKeeper集群中，有以下节点是属于 Kafka的，主要用于存储Kafka的元数据信息

- cluster
- controller_epoch
- brokers
- admin
- isr_change_notification
- consumers
- latest_producer_id_block
- config

## 3 - Kafka 架构深入

### 3.1 Kafka 工作流程及文件存储机制

![](http://witty-hamster.gitee.io/draw-bed/Kafka/Kafka工作流程.png)

​	Kafka 中消息是以 **topic**进行分类的，生产者生产消息，消费者消费消息，都是面向 topic的。

​	**topic 是逻辑上的概念，而 partition 是物理上的概念**，每个 partition对应于一个 log文件，该 log文件中存储的就是 producer生产的数据。producer生产的数据会被不断追加到该 log文件末端，且每条数据都有自己的 offset。消费者组中的每个消费者，都会实时记录自己消费到了哪个 offset，以便出错恢复时，从上次的位置继续消费。

![](http://witty-hamster.gitee.io/draw-bed/Kafka/Kafka文件存储机制.png)

​	由于生产者生产的消息会不断追加到 log文件末尾，为防止 log文件过大导致数据定位效率低下，Kafka采取了**分片**和**索引**机制，将每个 partition 分为多个 segment。每个 segment对应两个文件 —— `.index`文件和 `.log`文件。这些文件位于一个文件夹下，该文件夹的命名规则为：`topic名称 + 分区序号`。例如：first这个 topic有三个分区，则其对应的文件夹为 first-0，first-1，first-2。

​	某个分区内的内容可能如下所示：

```sh
00000000000000000000.index
00000000000000000000.log
00000000000000170410.index
00000000000000170410.log
00000000000000239430.index
00000000000000239430.log
```

​	`.index`和`.log`文件以当前segment的第一条消息的 offset命名。下图为 index文件和 log文件的结构示意图：

![](http://witty-hamster.gitee.io/draw-bed/Kafka/index文件与log文件详解.png)



​	`.index`文件存储大量的索引信息，`.log`文件存储大量的数据，索引文件中的元数据指向对应数据文件中 message的物理偏移地址。

​	`.index`文件中每条数据的大小是一致的，并且每条数据存储了`索引 => {message的物理偏移量，message的大小}`

​	在消费消息时，先会去通过 **二分查找**的方式，查找索引在哪个 `.index`文件中，之后找到消费的索引，通过索引对应的值，来进行数据文件的消费。

### 3.2 Kafka 生产者

#### 3.2.1 分区策略

##### 1 分区的原因

- <b style="color:#FF1744">方便在集群中扩展</b>，每个Partition可以通过调整以适应它所在的机器，而一个 topic又可以有多个 Partition组成，因此整个集群就可以适应任意大小的数据了。
- <b style="color:#FF1744">可以提高并发</b>，因为可以以 Partition为单位读写了。

##### 2 分区的原则

​	我们需要将 Producer发送的数据封装成一个 <b style="color:#FF1744">ProducerRecord</b>对象。

![](http://witty-hamster.gitee.io/draw-bed/Kafka/ProducerRecord对象.png)

- 原则一：指明 Partition的情况下，直接将指明的值直接存储到指明的 Parition分区中；
- 原则二：没有指明 Partition值，但是有 key的情况下，将 key的 hash值与topic的 partition个数进行取余得到 parition分区号；
- 原则三：既没有 Partition值也没有 key值的情况下，第一次调用时随机生成一个整数（后面每次调用在这个整数上自增），将这个值与 topic可用的 partition总数取余得到 partition的分区号，也就是常说的 round-robin(轮询)算法。

#### 3.2.2 数据可靠保证

​	<b style="color:#FF1744">为保证 producer 发送的数据，能可靠的发送到指定的 topic，topic的每个 partition收到 producer发送的数据后，都需要向 Producer发送 ACK（acknowledgement，确认收到），如果 Producer收到 ACK，就会进行下一轮的发送，否则重新发送数据。</b>

![](http://witty-hamster.gitee.io/draw-bed/Kafka/ack应答.png)

##### 1 副本数据同步策略

| 方案                             | 优点                                                   | 缺点                                                      |
| -------------------------------- | ------------------------------------------------------ | --------------------------------------------------------- |
| **半数以上完成同步，就发送 ACK** | 延迟低                                                 | 选举新的 leader时，容忍 n台节点的故障，需要 2n + 1 个副本 |
| **全部完成同步，才发送 ACK**     | 选举新的 leader时，容忍 n台节点的故障，需要 n+1 个副本 | 延迟高                                                    |

- Kafka 选择了第二种方案（全部完成同步，才发送 ACK），原因如下：
  - 同样为了容忍 n台节点的故障，第一种方案需要 2n + 1个副本，而第二种方案只需要 n + 1个副本，而 Kafka的每个分区都有大量的数据，第一种方案会造成大量数据的冗余。
  - 虽然第二种方案的网络延迟会比较高，但网络延迟对 Kafka的影响较小。

##### 2 ISR 同步副本队列

​	采用第二种方案之后，设想以下情景：leader收到数据，所有 follower都开始同步数据，但有一个 follower，因为某种故障，迟迟不能与 leader进行同步，那么 leader就要一直等下去，直到它完成同步，才能发送 ACK。这个问题怎么解决呢？

​	<b style="color:#FF1744">Leader 维护了一个动态的 in-sync replica set（ISR），意为和 Leader保持同步的 follower集合。当 ISR中的follower完成数据的同步之后，Leader就会给 follower发送 ACK。如果 follower长时间未向 Leader同步数据，则该 follower将被踢出 ISR，该时间阈值由 `replica.log.time.max.ms`参数设定。Leader发送故障之后，就会从 ISR中选举新的 Leader。</b>

​	0.9.0版本之前，ISR同步数据选取副本时，需要设置两个参数：`replica.lag.max.messages`(如果一个副本落在leader后面的消息超过这个数量，leader就会将follower从ISR中移除，并将其视为死亡。)，`replica.lag.time.max.ms`(如果一个follower在这个时间段内没有发送任何获取请求，leader将从ISR(同步副本)中删除该追随者，并将其视为死亡。)

​	0.9.0版本开始之后，ISR同步数据选取副本仅通过设置 `replica.lag.time.max.ms`参数即可

##### 3 ACK应答机制

​	对于某些不太重要的数据，对数据的可靠性要求不是很高，能够容忍数据的少量丢失，所以没必要等 ISR中的 follower全部接收成功。

​	所以，Kafka为用户提供了三种可靠性级别，用户根据对可靠性和延迟的要求进行权衡，选择一下的配置。

**acks 参数配置**：

- acks

  - `0`：Producer 不等待 broker的 ack，这一操作提供了一个最低的延迟，broker一接收到还没有写入磁盘就已经返回，当 broker故障时有可能<b style="color:#FF1744">丢失数据</b>。

  - `1`：Producer 等待 broker的 ack，Partition的 leader落盘成功后返回 ack，如果在 follower同步成功之前 leader故障，那么将会<b style="color:#FF1744">丢失数据</b>。

    ![](http://witty-hamster.gitee.io/draw-bed/Kafka/acks=1时数据丢失案例.png)

  - `-1(all)`：Producer 等待 broker的 ack，Partition的 leader和 follower（这里的 follower指的是 ISR队列中的）全部落盘成功后才返回 ack。但是如果在 follower同步完成后，broker发送 ack之前，leader发生故障，那么会造成<b style="color:#FF1744">数据重复</b>。

    ![](http://witty-hamster.gitee.io/draw-bed/Kafka/acks=-1数据重复案例.png)

    - 当 `acks=-1`时，在极限情况下，也可能造成<b style="color:#FF1744">数据丢失</b>，例如：有3个副本，1个leader，2个follower。当两个 follower的网络延迟较高时，并没有加入到 ISR同步副本队列，此时 ISR中仅有一个 leader，当 leader成功接收数据后，会直接给 Producer返回 ack应答，但此时follower并没有同步数据，如果 leader这个时候挂掉了，那么就会造成数据丢失。

##### 4 故障处理细节

> 解决数据一致性问题，数据一致性分为两个部分：
>
> - 消费者消费数据的一致性问题
> - 存储数据的一致性问题

![](http://witty-hamster.gitee.io/draw-bed/Kafka/Log文件中的HW和LEO.png)

- LEO：指的是每个副本最大的 offset
- HW：指的是消费者能见到的最大的 offset，ISR队列中最小的 LEO

- **follower 故障**：
  - follower 发送故障后会被临时踢出 ISR，待该 follower恢复后，follower会读取本地磁盘记录的上次的HW，并将 log文件高于 HW的部分截取掉，从 HW开始向 leader进行同步。等该 follower的 LEO大于等于该 Partition的 HW，即 follower追上 leader之后，就可以重新加入 ISR了。
- **leader 故障**：
  - leader 发生故障之后，会从 ISR中选出一个新的 leader，之后，为保证多个副本之间的数据一致性，其余的 follower会先将各自的 log文件高于 HW的部分截取掉，然后从新的 leader同步数据。

<b style="color:#FF1744">注意：这里只能保证副本之间的数据一致性，并不能保证数据不丢失或者不重复（保证数据不丢失或不重复的是 ACK）</b>

#### 3.2.3 Exactly Once（精准一次） 语义

​	将服务器的 ACK级别设置为 -1，可以保证 Producer到 Server之间不会丢失数据，即 <b style="color:#FF1744">At Least Once（至少一次）语义</b>。相对的，将服务器 ACK级别设置为0，可以保证生产者每条消息只会被发送一次，即 <b style="color:#FF1744">At Most Once（最多一次）</b>语义。

​	At Least Once 可以保证数据不丢失，但是不能保证数据不重复；相对的，At Most Once可以保证数据不重复，但是不能保证数据不丢失。<b style="color:#FF1744">但是，对于一些非常重要的信息，比如说，交易数据，下游数据消费者要求数据既不重复也不丢失，即 Exactly Once（精准一次）语义</b>。在 0.11 版本以前的Kafka，对此是无能为力的，只能保证数据不丢失，需要在下游消费者对数据做全局去重。对于多个下游应用的情况，每个都需要单独做全局去重，这就对性能造成了很大的影响。

​	在 0.11版本的Kafka中，引入了一项重大特性：**幂等性**。所谓的幂等性，就是指 Producer不论向 Server发送多少次重复数据，Server端都只会持久化一条。幂等性结合 At Least Once语言，就构成了 Kafka的 Exactly Once语义。即：
$$
At Least Once + 幂等性 = Exactly Once
$$
​	要启动幂等性，只需要将 Producer的参数中 `enable.idompotence`设置为 true即可（只要开启了幂等性，那么ACK机制的参数默认为 -1）。Kafka的幂等性实现其实就是将原来下游需要做的去重放在了数据上游。开启幂等性的 Producer在初始化的时候会被分配一个 PID（Producer ID），发往同一个 Partition的消息会附带 Sequence Number。而 Broker端会对<PID，Partition，SeqNumber>做缓存，当具有相同主键的消息提交时，Broker只会持久化一条。

​	但是，Producer重启就会改变PID，同时不同的 Partition也具有不同的主键，所以<b style="color:#AA00FF">幂等性无法保证跨分区会话的 Exactly Once</b>。

### 3.3 Kafka 消费者

#### 3.3.1 消费方式

​	<b style="color:#FF1744">Consumer 采用 pull（拉）模式从 broker中读取数据。</b>

​	<b style="color:#FF1744">push（推）模式很难适应消费速率不同的消费者，因为消息发送速率是由 broker决定的。</b>它的目标是尽可能以最快速度传递消息，但是这样很容易造成 Consumer来不及处理消息，典型的表现就是拒绝服务以及网络阻塞。而 pull模式则可以根据 Consumer的消费能力以适当的速率消费消息。

​	<b style="color:#FF1744">pull 模式的不足之处是，如果 Kafka没有数据，消费者可能会陷入循环中，一直返回空数据</b>。针对这一点，Kafka的消费者在消费数据时会传入一个时长参数 timeout，如果当前没有数据可供消费，Consumer会等待一段时间之后再返回，这段时长即为 timeout。

#### 3.3.2 分区分配策略

​	一个 Consumer group中有多个 Consumer，一个 topic有多个 Partition，所以必然会涉及到 Partition的分配问题，即确定哪个 Partition由哪个 Consumer来消费。

​	Kafka 有两种分配策略，一是 RoundRobin（轮询），一是 Range（范围）。

##### 1 RoundRobin（轮询）

​	RoundRobin 分配策略面向的是 **消费者组**，它会将一个消费者组消费的所有topic的 partition对象获取到，获取 partition对象的 Hash值，通过 Hash值对所有的对象进行排序，之后按照顺序将每一个partition对象分配给消费者组中的消费者。

​	该分配方式可以保证数据均匀的分配到每一个消费者（消费者与消费者之间数据最多仅相差一个 partition），但是也存在一个缺点，就是一个消费者不能针对一个 topic进行消费，它会把消费者组消费的所有的 topic获取到，重新排序再分配。

##### 2 Range（范围）

​	Range 分配策略面向的是 **topic**，它会根据主题进行分组，如果一个消费者组（含有3个消费者）消费的是同一个主题（含有7个分区），那么 partition分配的策略就是，将所有的分区个数除以所有的消费者个数，此时有一个消费者消费 3个分区，另外两个消费者消费 2个分区。

​	该分配方式可以保证同一个主题可以被一个消费者消费，但是也存在一个缺点，有可能导致消费者消费的数据不均匀。

##### 3 什么时候会触发分区分配策略？

​	当消费者组中消费者个数发生变化的时候（包括消费者的增加或者减少），都会导致重新分配分区。即使消费者组中消费者的个数大于分区个数的时候，当有消费者增加或减少时，仍然会重新分配。

#### 3.3.3 offset 的维护

​	由于 Consumer 在消费过程中可能会出现断电宕机等故障，Consumer 恢复后，需要从故障前的位置继续消费，所以 Consumer 需要实时记录自己消费到了哪个 offset，以便故障恢复后继续消费。

##### 1 如何确定一个 offset？

$$
Consumer Group(消费者组) + Topic(主题) + Partition(分区号) => offset(消费偏移量)
$$

​	由 消费者组 + 主题 + 分区编号唯一确定一个 offset。

##### 2 Zookeeper中 Kafka存储有哪些节点？

![](http://witty-hamster.gitee.io/draw-bed/Kafka/Kafka在Zookeeper中的节点.png)

- 各节点解读
  - `controller_epoch`：存储集群中的中央控制器选举的次数
  - `controller`：存储中央控制器 brokerId等信息
  - `brokers`：集群
  - `consumers`：存储消费者组中消费的偏移量offset
  - `config`：存储 Kafka的配置信息

​	<b style="color:#FF1744">Kafka 0.9版本之前，Consumer 默认将 offset保存在 Zookeeper中，从 0.9版本开始，Consumer 默认将 offset保存在 Kafka一个内置的 topic中，该 topic为 `__consumer_offsets`。</b>

##### 3 消费`__consumer_offsets`主题下的offset

- 修改配置文件 `consumer.properties`

  ```sh
  exclude.internal.topics = false
  ```

  Kafka系统的主题对于用户来说是禁止消费的，如果我们想要消费系统的主题，那么就需要添加上述配置。

- 读取 offset

  - 0.11.0.0 之前的版本：

    ```sh
    bin/kafka-console-consumer.sh --topic __consumer_offsets --zookeeper node01:2181 --formatter "kafka.coordinator.GroupMetadataManager\$OffsetsMessageFormatter" --consumer.config config/consumer.properties --from-beginning
    ```

  - 0.11.0.0 之后版本（含）：

    ```sh
    bin/kafka-console-consumer.sh --topic __consumer_offsets --zookeeper node01:2181 --formatter "kafka.coordinator.group.GroupMetadataManager\$OffsetsMessageFormatter" --consumer.config config/consumer.properties --from-beginning
    ```

- 消费者如何在 `__consumer_offsets`主题下的50个分区中定位到自己要消费的 offset的呢？

  - 主题中每个分区存储的数据是以 key-value对的形式存储的，消费者通过 `消费者组 + topic + partition`的Hash(哈希)值，便可以快速定位到需要消费的offset。

#### 3.3.4 消费者组案例

1. 需求：测试同一个消费者组中的消费者，同一时刻只能有一个消费者消费。

2. 案例实操

   - 在 node02、node03上修改 `/opt/module/kafka_2.11/config/consumer.properties`配置文件中的 `group.id`属性为任意组名，意为将消费者设置在同一个消费者组中

     - `group.id = test-bigdata`

   - 在 node02、node03上分别启动消费者

     ```sh
     bin/kafka-console-consumer.sh --topic bigdata --zookeeper node01:2181 --consumer.config config/consumer.properties
     ```

   - 在 node01 上启动生产者

     ```sh
     bin/kafka-console-producer.sh --topic bigdata --broker-list node01:9092
     ```

   - 通过查看可以发现，同一时刻只有一个消费者接收到消息。（因为一个消费者组中的一个消费者对应一个主题中的分区）

### 3.4 Kafka 高效读写数据

- 对于分布式 Kafka集群来说，为什么是高效的读写？
  - 因为Kafka中有分区的概念，这就增加了 Kafka的读写并行度，同一时间可同时进行读写操作
- 对于单台 Kafka来说，为什么是高效的读写？有以下两点
  - **顺序写磁盘**（磁盘寻址层面）
    - Kafka 的 Producer生产数据，要写入到 log文件中，写的过程是一直追加到文件末端，为顺序写。官网有数据表明，同样的磁盘，顺序写能到 600M/s，而随机写只有 100K/s。这与磁盘的机械机构有关，顺序写之所以快，是因为其省去了大量磁头寻址的时间。
  - **零复制技术(又称零拷贝)**（网络编程方面）
    - 省去了用户层面的操作，直接有操作系统来完成。

### 3.5 Zookeeper 在 Kafka中的作用

​	Kafka 集群中有一个 broker会被选举为 Controller，负责<b style="color:#FF1744">管理集群 broker的上下线</b>，所有 topic的<b style="color:#FF1744">分区副本分配</b>和 <b style="color:#FF1744">leader选举</b>等工作。(broker之间争抢资源，谁争抢到了，谁就是Controller)

​	Controller 的管理工作都是依赖于 Zookeeper的。

​	以下为 Partition 的leader选举过程：

![](http://witty-hamster.gitee.io/draw-bed/Kafka/Leader选举流程.png)

### 3.6 Kafka 事务

​	Kafka从 0.11 版本开始引入了事务支持。事务可以保证 Kafka在 Exactly Once语义的基础上，生产和消费可以跨分区和会话，要么全部成功，要么全部失败。

#### 3.6.1 Producer 事务

​	为了实现跨分区跨会话的事务，需要引入一个全局唯一的 Transaction ID（该 TID是由客户端给出的），并将 Producer 获得的 PID和 Transaction ID绑定。这样当 Producer重启后就可以通过正在进行的 Transaction ID获取到原来的 PID。

​	为了管理 Transaction，Kafka引入了一个新的组件 Transaction Coordinator。Producer 就是通过和 Transaction Coordinator 交互获得 Transaction ID对应的任务状态。Transaction Coordinator还负责将事务所有写入 Kafka的一个内部 Topic，这样即使整个服务重启，由于事务状态得到保存，进行中的事务状态可以得到恢复，从而继续进行。

​	`事务 + 幂等性`就可以保证在跨分区跨会话的情况下，还是可以保证数据精准一次，保证数据不重复。

#### 3.6.2 Consumer 事务

​	上述事务机制主要从 Producer方面考虑，对于 Consumer而言，事务的保证就会相对较弱，尤其是无法保证 Commit的信息被精准消费。这是由于 Consumer可以通过 offset访问任意信息，而且不同的 Segment File生命周期不同，同一事务的消息可能会出现重启后被删除的情况。

## 4 - Kafka API

### 4.1 Producer API

#### 4.1.1 消息发送流程

​	Kafka 的 Producer发送消息采用的是<b style="color:#FF1744">异步发送</b>的方式。在消息发送的过程中，涉及到了 <b style="color:#FF1744">两个线程（main线程和 Sender线程）</b>，以及<b style="color:#FF1744">一个线程共享变量（RecordAccumulator）</b>。

​	main线程将消息发送给 RecordAccumulator，Sender 线程不断从 RecordAccumulator中拉取消息发送到 Kafka broker。

![](http://witty-hamster.gitee.io/draw-bed/Kafka/KafkaProducer发送消息的流程.png)

- 相关参数说明：
  - `batch.size`：只有数据积累到 batch.size之后，sender才会发生数据。
  - `linge.ms`：如果数据迟迟未达到 batch.size，sender等待 linger.ms之后，就会发生数据。

#### 4.1.2 异步发送 API

- 导入依赖

  ```xml
  <!-- Kafka clients -->
  <!-- https://mvnrepository.com/artifact/org.apache.kafka/kafka-clients -->
  <dependency>
    <groupId>org.apache.kafka</groupId>
    <artifactId>kafka-clients</artifactId>
    <version>0.11.0.0</version>
  </dependency>
  ```

- 编写代码

  - 需要用到的类：
    - `KafkaProducer`：需要创建一个生产者对象，用来发送数据
    - `ProducerConfig`：获取所需的一系列配置参数
    - `ProducerRecord`：每条数据都要封装成一个 ProducerRecord对象
  - [不带回调函数的API](https://gitee.com/witty-hamster/z-hadoop/blob/master/z-kafka/src/main/java/com/hamster/demo/producer/MyProducer.java)
  - [带回调函数的API](https://gitee.com/witty-hamster/z-hadoop/blob/master/z-kafka/src/main/java/com/hamster/demo/producer/CallbackProducer.java)
    - 回调函数会在 Producer收到 ACK时调用，为异步调用，该方法有两个参数，分别是 RecordMetadata 和 Exception，如果 Exception为 null，说明消息发送成功，如果 Exception不为 null，说明消息发送失败。
    - <b style="color:#FF1744">注意：消息发送失败会自动重试，不需要我们在回调函数中手动重试。</b>

#### 4.1.3 同步发送 API

​	同步发送的意思就是，一条消息发送之后，会阻塞当前线程，直至返回 ack。

​	由于 send方法返回的是一个 Futrue对象，根据 Futrue对象的特点，我们也可以实现同步发送的效果，只需要在调用 Futrue对象的 get方法即可。

[自定义生产者 -- 同步发送消息](https://gitee.com/witty-hamster/z-hadoop/blob/master/z-kafka/src/main/java/com/hamster/demo/producer/SyncProducer.java)

### 4.2 Consumer API

​	Consumer 消费数据时的可靠性是很容易保证的，因为数据在 Kafka中是持久化的，故不用担心数据丢失问题。

​	由于 Consumer在消费过程中可能会出现断电宕机等故障，Consumer恢复后，需要从故障前的位置继续消费，所以 Consumer需要实时记录自己消费到了哪个 offset，以便故障恢复后继续消费。

​	所以，offset的维护时 Consumer消费数据必须考虑的问题。

#### 4.2.1 自动提交 offset

- 需要用到的类：
  - `KafkaConsumer`：需要创建一个消费者对象，用来消费数据
  - `ConsumerConfig`：获取所需的一系列配置参数
  - `ConsumerRecord`：每条数据都要封装成一个 ConsumerRecord 对象
- 为了使我们能够专注于自己的业务逻辑，Kafka提供了自动提交 offset的功能。
- 自动提交 offset的相关参数：
  - `enable.auto.commit`：是否开启自动提交 offset功能
  - `auto.commit.interval.ms`：自动提交 offset的时间间隔

[自定义消费者 -- 自动提交offset](https://gitee.com/witty-hamster/z-hadoop/blob/master/z-kafka/src/main/java/com/hamster/demo/consumer/MyConsumer.java)

如何实现消费者从头消费数据？

​	在设置参数时，需要设置 `AUTO_OFFSET_RESET_CONFIG`为 `earliest`。

​	并且需要设置一个新的消费者组，此时消费者将会从头开始消费数据，相当于在控制台添加了一个 `--from-beginning`

​	另外，当开启offset重置参数设置为`earliest`时，kafka中存储的offset被删除后，也将从头开始消费消息。

#### 4.2.2 手动提交 offset

​	虽然自动提交 offset十分简单便利，但是由于其是基于时间提交的，开发人员难以把握 offset提交的时机。因此 Kafka 还提供了手动提交 offset的API。

​	手动提交 offset的方法有两种：分别是 `commitSync（同步提交）`和 `commitAsync（异步提交）`。两者的相同点是，都会将<b style="color:#FF1744">本次 poll的一批数据最高的偏移量提交</b>；不同点是，`commitSync`阻塞当前线程，一直到提交成功，并且会自动失败重试（由不可控因素导致，也会出现提交失败）；而 commitAsync则没有失败重试机制，故有可能提交失败。

- 数据漏消费和重复消费分析
  - 无论是同步提交还是异步提交 offset，都有可能会造成数据的漏消费或者重复消费。先提交 offset后消费，有可能造成数据的漏消费；而先消费后提交 offset，有可能会造成数据的重复消费。
- [同步提交offset](https://gitee.com/witty-hamster/z-hadoop/blob/master/z-kafka/src/main/java/com/hamster/demo/consumer/CommitSyncConsumer.java)
  - 由于同步提交 offset有失败重试机制，故更加可靠。
- [异步提交offset](https://gitee.com/witty-hamster/z-hadoop/blob/master/z-kafka/src/main/java/com/hamster/demo/consumer/CommitAsyncConsumer.java)
  - 虽然同步提交 offset更可靠一些，但是由于其会阻塞当前线程，直到提交成功。因此吞吐量会受到很大的影响。因此更多的情况下，会选用异步提交 offset的方式。

#### 4.2.3 自定义存储 offset

​	Kafka 0.9版本之前，offset 存储在 Zookeeper中；0.9版本及之后，默认将 offset存储在 Kafka的一个内置的 topic中。除此之外，Kafka还可以选择自定义存储 offset。

​	offset的维护是相当繁琐的，因为需要考虑到消费者的 Rebalace。

​	<b style="color:#FF1744">当有新的消费者加入消费者组、已有的消费者退出消费者组或者订阅的主题的分区发生变化，就会触发到分区的重新分配，重新分配的过程叫做 Rebalance。</b>

​	消费者发送 Rebalance之后，每个消费者消费的分区就会发生变化。<b style="color:#FF1744">因此消费者要首先获取到自己被重新分配到的分区，并且定位到每个分区最近提交的 offset位置继续消费。</b>

​	要实现自定义存储 offset，需要借助 `ConsumerRebalanceListener`，以下为示例代码，其中提交和获取 offset的方法，需要根据所选的 offset存储系统自行实现。

[自定义存储 offset](https://gitee.com/witty-hamster/z-hadoop/blob/master/z-kafka/src/main/java/com/hamster/demo/consumer/RebalanceConsumer.java)

### 4.3 自定义 Interceptor

#### 4.3.1 拦截器原理

​	Producer 拦截器（interceptor）是在 Kafka 0.10版本被引入的，主要用于实现 clients端的定制化控制逻辑。

​	对于 Producer而言，interceptor使得用户在消息发送前以及 Producer回调逻辑前有机会对消息做一些定制化需求，比如<b style="color:#FF1744">修改消息</b>等。同时，Producer允许用户指定多个 interceptor按序作用于同一条消息从而形成一个拦截链（interceptor chain）。Interceptor 的实现接口是 `org.apache.kafka.clients.producer.ProducerInterceptor`，其定义的方法包括：

- `configure(configs)`：获取配置信息和初始化数据时调用。
- `onSend(ProducerRecord)`：该方法封装进 KafkaProducer.send 方法中，即它运行在用户主线程中。Producer 确保在消息被序列化以及计算分区前调用该方法。<b style="color:#FF1744">用户可以在该方法中对消息做任何操作，但最好保证不要修改消息所属的 topic和分区，</b>否则会影响目标分区的计算。
- `onAcknowledgement(RecordMetadata, Exception)`：<b style="color:#FF1744">该方法会在消息从 RecordAccumulator成功发送到 Kafka Broker之后，或者在发送过程中失败时调用。</b>并且通常都是在 Producer回调逻辑触发之前。onAcknowledgement 运行在 Producer的 IO线程中，因此不要在该方法中放入很重要的逻辑，否则会托慢 Producer的消息发送效率。
- `close()`：<b style="color:#FF1744">关闭 interceptor，主要用于执行一些资源清理工作</b>

如前所述，interceptor 可能被运行在多个线程中，因此在具体实现时用户需要自行确保线程安全。另外 <b style="color:#FF1744">倘若指定了多个 interceptor，则 producer将按照指定顺序调用它们</b>，并仅仅是捕捉每个 interceptor可能抛出的异常记录到错误日志中而非向上传递。这在使用过程中要特别留意。

#### 4.3.2 拦截器案例

1. 需求

   实现一个简单的双 interceptor组成的拦截链。第一个 interceptor会在消息发送前将时间戳信息加到消息 value的最前部；第二个 interceptor会在消息发送后更新成功发送消息数或失败发送消息数。

   ![](http://witty-hamster.gitee.io/draw-bed/Kafka/Kafka拦截器.png)

2. 参考代码

   [拦截器案例代码](https://gitee.com/witty-hamster/z-hadoop/blob/master/z-kafka/src/main/java/com/hamster/demo/interceptor/TimeInterceptor.java)

## 5 - Kafka监控

### 5.1 Kafka Eagle安装与配置

1. 修改 Kafka启动命令

   - 修改 `kafka-server-start.sh`命令中内容，主要是为了开启 JMX监控端口，用于监控Kafka的JMX

   ```sh
   # 找到以下配置
   if [ "x$KAFKA_HEAP_OPTS" = "x" ]; then
   	export KAFKA_HEAP_OPTS="-Xmx1G -Xms1G"
   fi
   
   # 修改成如下内容
   if [ "x$KAFKA_HEAP_OPTS" = "x" ]; then
   	export KAFKA_HEAP_OPTS="-server -Xms2G -Xmx2G -XX:PermSize=128m -XX:+UseG1GC -XX:MaxGCPauseMillis=200 -XX:ParallelGCThreads=8 -XX:ConcGCThreads=5 -XX:InitiatingHeapOccupancyPercent=70"
   	export JMX_PORT="9999"
   	# export KAFKA_HEAP_OPTS="-Xmx1G -Xms1G"
   fi
   ```

   <b style="color:#FF1744">注意：修改之后在启动Kafka之前，需要将启动文件分发到其他节点</b>

2. 上传压缩包 `kafka-eagle-bin-1.3.7.tar.gz`到集群 `/opt/software`目录

3. 解压到本地

   ```sh
   tar -zxvf kafka-eagle-bin-1.3.7.tar.gz
   ```

4. 进入到刚解压后的目录，解压目录下的 `kafka-eagle-web-1.3.7-bin.tar.gz`到`/opt/module`文件夹

   ```sh
   cd kafka-eagle-bin-1.3.7
   tar -zxvf kafka-eagle-web-1.3.7-bin.tar.gz -C /opt/module
   ```

5. 进入到 eagle目录下，给`bin`下的启动文件增加执行权限

   ```sh
   [root@node01 eagle]# cd bin/
   [root@node01 bin]# chmod 777 ke.sh
   ```

6. 修改 eagle的配置文件，修改如下内容

   ```properties
   ######################################
   # multi zookeeper&kafka cluster list
   ######################################
   # 修改监控的Kafka集群及zk地址（可同时监控多个Kafka集群、ZK集群）
   kafka.eagle.zk.cluster.alias=cluster1
   cluster1.zk.list=node01:2181,node02:2181,node03:2181
   
   ######################################
   # kafka offset storage
   ######################################
   # 指定消费的offset存储位置为kafka，也可存储在zookeeper中
   cluster1.kafka.eagle.offset.storage=kafka
   
   ######################################
   # enable kafka metrics
   ######################################
   # 开启监控中的视图
   kafka.eagle.metrics.charts=true
   kafka.eagle.sql.fix.error=false
   
   ######################################
   # alarm email configure
   ######################################
   # 实际工作中可以开启邮箱配置，用于发送异常情况，建议使用`@163`邮箱
   kafka.eagle.mail.enable=false
   kafka.eagle.mail.sa=alert_sa@163.com
   kafka.eagle.mail.username=alert_sa@163.com
   kafka.eagle.mail.password=mqslimczkdqabbbh
   kafka.eagle.mail.server.host=smtp.163.com
   kafka.eagle.mail.server.port=25
   
   ######################################
   # kafka jdbc driver address
   ######################################
   # 设置MySQL连接，使用MySQL存储监控数据
   kafka.eagle.driver=com.mysql.jdbc.Driver
   kafka.eagle.url=jdbc:mysql://node01:3306/ke?useUnicode=true&characterEncoding=UTF-8&zeroDateTimeBehavior=convertToNull
   kafka.eagle.username=root
   kafka.eagle.password=123456
   ```

   <b style="color:#FF1744">注意：可以不用手动创建 eagle的MySQL数据库，在开启 eagle后会自动创建MySQL数据库</b>

7. 添加环境变量

   ```sh
   export KE_HOME=/opt/module/eagle
   export PATH=$PATH:$KE_HOME/bin
   ```

   <b style="color:#FF1744">注意：需要使用 `source /etc/profile`使修改后的环境变量生效</b>

8. 启动

   ```sh
   [root@node01 eagle]# bin/ke.sh start
   ... ...
   ... ...
   *******************************************************************
   * Kafka Eagle system monitor port successful... 
   *******************************************************************
   [2020-11-13 12:07:03] INFO: Status Code[0]
   [2020-11-13 12:07:03] INFO: [Job done!]
   Welcome to
       __ __    ___     ____    __ __    ___            ______    ___    ______    __     ______
      / //_/   /   |   / __/   / //_/   /   |          / ____/   /   |  / ____/   / /    / ____/
     / ,<     / /| |  / /_    / ,<     / /| |         / __/     / /| | / / __    / /    / __/   
    / /| |   / ___ | / __/   / /| |   / ___ |        / /___    / ___ |/ /_/ /   / /___ / /___   
   /_/ |_|  /_/  |_|/_/     /_/ |_|  /_/  |_|       /_____/   /_/  |_|\____/   /_____//_____/   
                                                                                                
   
   Version 1.3.7
   *******************************************************************
   * Kafka Eagle Service has started success.
   * Welcome, Now you can visit 'http://192.168.131.100:8048/ke'
   * Account:admin ,Password:123456
   *******************************************************************
   * <Usage> ke.sh [start|status|stop|restart|stats] </Usage>
   * <Usage> https://www.kafka-eagle.org/ </Usage>
   *******************************************************************
   ```

   <b style="color:#FF1744">注意：启动之前需要先启动 ZK以及 Kafka</b>

9. 登录界面查看监控数据

   [监控的web界面访问地址可通过启动命令行中找到](http://192.168.131.100:8048/ke)

   <b style="color:#FF1744">注意：登录eagle的web界面是需要用户名及密码的，也是在启动命令行中可以找到</b>

   ![](http://witty-hamster.gitee.io/draw-bed/Kafka/KafkaEagle监控界面.png)

## 6 - Flume 对接 Kafka

### 6.1 基础配置版

​	将数据发往 Kafka某一个指定的主题 topic

```properties
# Flume对接Kafka
# Name
a1.sources = r1
a1.sinks = k1
a1.channels = c1

# Sources
a1.sources.r1.type = netcat
a1.sources.r1.bind = localhost
a1.sources.r1.port = 44444

# channels
a1.channels.c1.type = memory
a1.channels.c1.capacity = 1000
a1.channels.c1.transactionCapacity = 100

# Sinks
a1.sinks.k1.type = org.apache.flume.sink.kafka.KafkaSink
a1.sinks.k1.kafka.topic = bigdata
a1.sinks.k1.kafka.bootstrap.servers = node01:9092,node02:9092,node03:9092
a1.sinks.k1.kafka.flumeBatchSize = 20
a1.sinks.k1.kafka.producer.acks = 1
a1.sinks.k1.kafka.producer.linger.ms = 1

# bind
a1.sources.r1.channels = c1
a1.sinks.k1.channel = c1
```

### 6.2 数据分离操作

​	根据数据内容的不同，将不同数据发送到不同的主题中，需要使用到 Flume 的拦截器，在消息头中添加`"topic": "topic_name"`键值对形式。注意，键必须为`topic`，这样直接通过 Kafka Sink便可以将数据区分到不同的主题中，这是Kafka Sink的一个特殊功能。

[Flume过滤数据到不同Kafka Topic的拦截器](https://gitee.com/witty-hamster/z-hadoop/blob/master/z-flume/src/main/java/com/hamster/demo/interceptor/KafkaInterceptor.java)

- 配置文件信息如下：

```properties
# Flume对接Kafka，根据数据内容区分Kafka主题
# Name
a1.sources = r1
a1.sinks = k1
a1.channels = c1

# Sources
a1.sources.r1.type = netcat
a1.sources.r1.bind = localhost
a1.sources.r1.port = 44444

# channels
a1.channels.c1.type = memory
a1.channels.c1.capacity = 1000
a1.channels.c1.transactionCapacity = 100

# Sinks
a1.sinks.k1.type = org.apache.flume.sink.kafka.KafkaSink
a1.sinks.k1.kafka.bootstrap.servers = node01:9092,node02:9092,node03:9092
a1.sinks.k1.kafka.flumeBatchSize = 20
a1.sinks.k1.kafka.producer.acks = 1
a1.sinks.k1.kafka.producer.linger.ms = 1

# Interceptor
a1.sources.r1.interceptors = i1
a1.sources.r1.interceptors.i1.type = com.hamster.demo.interceptor.KafkaInterceptor$Builder

# bind
a1.sources.r1.channels = c1
a1.sinks.k1.channel = c1
```

## 7 - Kafka 面试题

### 7.1 面试问题

1. Kafka 中的 ISR(InSyncRepli)、OSR(OutSyncRepli)、AR(AllRepli) 代表什么？
2. Kafka 中的 HW、LEO 等分别代表什么？
3. Kafka 中是怎么体现消息顺序性的？
   - 区内有序
4. Kafka 中的分区器、序列化器、拦截器是否了解？它们之间的处理顺序是什么？
5. Kafka 生产者客户端的整体结构是什么样子的？使用了几个线程来处理？分别是什么？
6. “消费者组中的消费者个数如果超过 topic的分区，那么就会有消费者消费不到数据” 这句话是否正确？
7. 消费者提交消费位移时提交的是当前消费到的最新消息的 offset 还是 offset + 1？
   - 提交的是 `offset + 1`
8. 有哪些情形会造成重复消费？
9. 哪些情景会造成消息漏消费？
10. 当你使用 kafka-topics.sh 创建（删除）了一个 topic之后，Kafka背后会执行什么逻辑？
    - 会在 zookeeper 中的 `/brokers/topics`节点下创建一个新的 topic节点，如：`/brokers/topics/first`
    - 触发 Controller的监听程序
    - Kafka Controller 负责 topic的创建工作，并更新 metadata cache
11. topic 的分区数可不可以增加？如果可以怎么增加？如果不可以，那又是为什么？
12. topic 的分区数可不可以减少？如果可以怎么减少？如果不可以，那又是为什么？
13. Kafka 有内部的 topic吗？如果有是什么？有什么所用？
14. Kafka 分区分配的概念？
15. 简述 Kafka 的日志目录结构？
16. 如果我指定了一个 offset，Kafka Controller怎么查找到对应的消息？
17. 聊一聊 Kafka Controller 的作用？
18. Kafka 中有哪些地方需要选举？这些地方的选举策略又有哪些？
19. 失效副本是指什么？有哪些应对措施？
20. Kafka 的哪些设计让它有如此高的性能？





​	





























---

<b style="color:#FF1744">红色</b>

<b style="color:#536DFE">蓝色</b>

<b style="color:#00C853">绿色</b>

<b style="color:#AA00FF">紫色</b>

<b style="color:#F57F17">橙色</b>

