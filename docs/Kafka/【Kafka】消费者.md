[TOC]

> KafkaConsumer 向 Kafka 订阅主题，进行消费

# 1. KafkaConsumer 相关概念

## 1.1 消费者 & 消费者群组

### 1.1.1 :thinking: 思考：如果生产者写入消息的速度远远大于消费者读取消息的速度，怎么办？

- 如果只使用单个消费者处理消息，消费者会远跟不上消息生成的速度
- 此时，有必要对消费者进行横向伸缩。使用多个消费者从同一个主题读取消息，对消息进行分流。

### 1.1.2 消费者

- 用于订阅 Kafka 主题，并读取消息进行消费

### 1.1.3 消费者群组

- 多个消费者组成一个消费者群组。一个群组里的消费者订阅的是同一个主题，每个消费者接收主题一部分分区的消息。

- 群组模型

  <img src="http://witty-hamster.gitee.io/draw-bed/Kafka/两个消费者群组对应一个主题模型.png" alt="两个消费者群组对应一个主题模型" style="zoom:50%;" />

  - <b style="color: #ff0000">为每一个需要获取一个或多个主题全部消息的应用程序创建一个消费者群组，然后往群组里添加消费者来伸缩读取能力和处理能力，群组里的每一个消费者只处理一部分消息。</b>
  - <b style="color: #ff0000">注意：群组中的消费者个数不要大于主题分区个数，如果消费者个数大于主题分区数，那多余的消费者则会空闲，则将浪费资源。</b>

## 1.2 :star2: 分区再均衡

- 当群组中的某一个消费者宕机、崩溃，或主题添加了新的分区，导致分区重启分配时，分区的所有权从一个消费者转移到另一个消费者，这样的行为被称为 ***再均衡*** 

- 优势：

  - 消费者群组高可用
  - 消费者群组伸缩性
  - 可以放心的添加或移除群组中的消费者

- 劣势：

  - 在再均衡期间，消费者无法去读消息，造成整个群组一小段时间不可用
  - 当分区被重新分配给另一个消费者时，消费者当前的读取状态会丢失
  - 有可能还需要去刷新缓存

- :thinking: 如何安全的再均衡？如何避免不必要的再均衡？

  - 消费者通过向被指派为 ***群组协调器*** 的broker（不同的群组可以有不同的协调器）发送 ***心跳*** 来维持它们和群组的从属关系以及它们对分区的所有权关系。
  - 只要消费者以正常的时间间隔发送心跳，就被认为是活跃的，说明它还在读取分区里的消息。
  - 消费者会在轮询消息（为了读取消息）或提交偏移量时发送心跳。如果消费者停止发送心跳的时间足够长，会话就会过期，群组协调器认为当前消费者已经死亡，就会触发一次再均衡。
  - 如果一个消费者发生崩溃，并停止读取消息，群组协调器会等待几秒钟，确认它死亡了才会触发再均衡。在这几秒钟里，死掉的消费者不会读取分区里的消息。在清理消费者时，消费者会通知协调器它将要离开群组，协调器会立即触发一次再均衡，尽量降低处理停顿。

- :top: 分配分区的过程

  > 这个过程在每次再均衡时，会重复发生

  - 当消费者要加入群组时，它会向群组协调器发送一个 JoinGroup 请求。第一个加入群组的消费者将成为 "群主"。
  - 群主从协调器那里获得群组的成员列表（列表中包含了所有最近发送过心跳的消费者，他们被认为是活跃的），并负责给每一个消费者分配分区。
  - 群主使用一个实现了 PartitionAssignor 接口的类来决定哪些分区应该被分配给哪个消费者
  - 分配完成后，群主将把分配请求列表发送给群组协调器，协调器再把这些信息发送给所有消费者。每个消费者只能看到自己的分配信息，只有群主知道群组里所有消费者的分配信息

# 2. 创建、订阅主题、消费

## 2.1 创建消费者

> 与生产者类似，同样需要三个必要的属性：bootstrap.servers、key.deserializer、value.deserializer

- 三个必要属性说明

  - `bootstrap.servers`：指定了Kafka集群的连接字符串
  - `key.deserializer`：反序列化key的字节数组类型转换成Java对象
  - `value.deserializer`：反序列化value的字节数组类型转换成Java对象

- 额外的一个非必传属性

  - `group.id`
    - 它指定了 KafkaConsumer 属于哪个消费者群组
    - 当不指定该属性值时，将创建一个不属于任何一个群组的消费者

- 消费者创建示例（最基础示例）

  ```java
  package com.hamster.kafka.consumer;
  
  import com.alibaba.fastjson.JSON;
  import org.apache.kafka.clients.consumer.KafkaConsumer;
  import org.apache.kafka.clients.producer.KafkaProducer;
  
  import java.util.Properties;
  
  /**
   * <p>
   *     创建消费者示例
   * </p>
   *
   * @author hamster
   * @date 2022/1/19 上午10:45
   */
  public class CreateConsumerEg {
  
      /**
       * 示例 - 创建消费者的基础步骤
       * @param args
       */
      public static void main(String[] args) {
          // STEP 1. 新建一个 Properties 配置对象，底层为 HashTable
          Properties kafkaProps = new Properties();
          // STEP 2. 通过 k-v 对形式，设置Kafka的必要配置信息
          kafkaProps.put("bootstrap.servers", "localhost:9092");
          kafkaProps.put("key.deserializer", "org.apache.kafka.common.serialization.StringDeserializer");
          kafkaProps.put("value.deserializer", "org.apache.kafka.common.serialization.StringDeserializer");
          kafkaProps.put("group.id", "test-group");		// 指定消费者群组
          // STEP 3. 创建一个新的消费者对象，将配置信息传入给Kafka生产者
          KafkaConsumer<Object, Object> consumer = new KafkaConsumer<>(kafkaProps);
          System.err.println("新建Kafka消费者 => " + JSON.toJSONString(consumer));
      }
  }
  
  ```

## 2.2 订阅主题 & 消费

### 2.2.1 订阅主题通用模式

- 基础模型
  - `KafkaConsumer#subscribe(Collection<String> topics, ConsumerRebalanceListener listener)`
  - 该方法有重写方法
    - 可以以一个 `Collection<String>` 集合的形式，指定消费者需要订阅的主题
    - 可以以一个正则表达式的形式，指定模糊匹配的订阅主题
      - 在使用正则表达式时，如果有新的主题被增加，并且新的主题名字与正则表达式匹配，那么将立即触发一次再均衡，消费者就可以读取到新的主题
- 假设要订阅所有与 test 相关的主题
  - 做法：`consumer.subscribe("test.*");`

### 2.2.2 轮询

> 消费者API的核心 —— 消费轮询

- 消费者订阅消息后，消息的细节处理过程都将交由轮询来处理，包括以下几个重要过程

  - 群组协调
  - 分区再均衡
  - 发送心跳
  - 获取数据

- 轮询示例代码

  ```java
  package com.hamster.kafka.consumer.receive;
  
  import com.alibaba.fastjson.JSON;
  import com.hamster.kafka.consumer.NewConsumer;
  import lombok.extern.slf4j.Slf4j;
  import org.apache.kafka.clients.consumer.ConsumerRecord;
  import org.apache.kafka.clients.consumer.ConsumerRecords;
  import org.apache.kafka.clients.consumer.KafkaConsumer;
  
  import java.time.Duration;
  import java.util.Collections;
  import java.util.Map;
  import java.util.concurrent.ConcurrentHashMap;
  
  /**
   * <p>
   *     消息轮询 - 消费者核心
   * </p>
   *
   * @author hamster
   * @date 2022/1/19 上午11:10
   */
  @Slf4j
  public class RoundRobinMessage {
  
      /** 消息内容统计 */
      private static final Map<String, Integer> custCountryMap = new ConcurrentHashMap<>();
  
      public static void main(String[] args) {
          KafkaConsumer<String, String> consumer = NewConsumer.builder("test-group");
  
          // 订阅消费主题(订阅一个单一主题)
          consumer.subscribe(Collections.singletonList("test"));
          try {
              // 轮询消费
              while (true) {
                  /*
                   *【重要】消费者持续对Kafka进行轮询，否则会被认为消费者已经死亡
                   *  - poll() 方法的参数是一个超时时间，用于控制 poll() 方法的阻塞时间（在消费者的缓存区里没有可用数据时会发生阻塞）
                   *  - 如果该参数设置为 0，poll() 会立即返回，否则它会在指定的毫秒内一直等待 broker 返回数据
                   */
                  ConsumerRecords<String, String> records = consumer.poll(Duration.ofMillis(100));
                  /*
                   * poll() 方法返回一个消息记录列表
                   *  每条记录都包含了记录所属的主题、所属分区、分区中的偏移量、键值对
                   */
                  for (ConsumerRecord<String, String> record : records) {
                      log.debug("topic = {}, partition = {}, offset = {}, customer = {}, country = {}",
                              record.topic(), record.partition(), record.offset(), record.key(), record.value());
  
                      int updatedCount = 1;
                      if (custCountryMap.containsKey(record.value())) {
                          updatedCount = custCountryMap.get(record.value()) + 1;
                      }
                      custCountryMap.put(record.value(), updatedCount);
                  }
                  log.info("count message = {}", JSON.toJSONString(custCountryMap));
              }
          } finally {
              /* 主动关闭消费者资源，可以立即触发一次再均衡，避免整个群组在一段时间内无法读取消息 */
              consumer.close();
          }
      }
  }
  
  ```

### 2.2.3 配置消费者

> 核心配置项：
>
> - `bootstrap.servers`
> - `group.id`
> - `key.deserializer`
> - `value.deserializer`
>
> 其他配置项如下：

#### `fetch.min.bytes`

- 指定了消费者从服务器获取记录的最小字节数
- 如果broker在收到消费者的数据请求时，可用的数据量小于该属性配置的指定大小时，那么borker会等到有足够的可用数据时，才将数据返回给消费者
- 优点：降低消费者和broker的工作负载

#### `fetch.max.wait.ms`

- 指定了broker的等待时间
- 默认值：500ms
- 工作流程
  - 如果没有足够的数据流入 Kafka，消费者获取最小数据量的要求就得不到满足，最终导致 500ms的延迟
- 与 `fetch.min.bytes` 属性共同作用，两个属性值哪个先达到上限，按照哪个属性来执行消息处理

#### `max.partition.fetch.bytes`

- 指定了服务器从每个分区里返回给消费者的最大字节数
- 默认值：1MB
- `KafkaConsumer#poll()` 方法从每个分区里返回的记录最多不超过 `max.partition.fetch.bytes` 指定的字节

#### `session.timeout.ms`

- 指定了消费者在被认为死亡之前可以与服务器断开连接的时间
- 默认值：3s
  - 将值设置的更小，就可以更快地检测和恢复崩溃的节点
  - 将值设置的大一点，可以减少意外的再均衡
- 如果消费者没有在 `session.timeout.ms` 指定的时间内发送心跳给群组协调器，就被认为已经死亡，协调器就会触发再均衡，把分区分配给群组里的其他消费者
- 该属性与 `heartbeat.interval.ms` 密切相关
  - `heartbeat.interval.ms` 指定了 poll() 方法向协调器发送心跳的频率
  - `session.timeout.ms` 指定了消费者可以多久不发送心跳
  - 一般情况，`heartbeat.interval.ms` 是 `session.timeout.ms` 所设置值的三分之一

#### `auto.offset.reset`

- 指定了消费者在读取一个没有偏移量的分区或者偏移量无效的情况下该作何处理
- 默认值：latest
  - 在<b style="color:#ff0000">偏移量无效</b>的情况下，消费者将从最新的记录开始读取数据（在消费者启动之后生成的记录）
- 另一个可选值：earliest
  - 在<b style="color:#ff0000">偏移量无效</b>的情况下，消费者将从起始位置读取分区的记录

#### `enable.auto.commit`

- 指定了消费者是否自动提交偏移量
- 默认值：true
  - 为了尽量避免出现重复数据和丢失数据，可以将其设置为 false，交由我们自己来控制何时提交偏移量
  - 如果采用默认值，可以通过 `auto.commit.interval.ms` 属性来控制提交的频率

#### `partition.assignment.strategy`

- `PartitionAssignor` 根据给定的消费者和主题，决定哪些分区应该被分配给哪个消费者
- 默认策略：Range
  - 参考：`org.apache.kafka.clients.consumer` 包下的类 
  - 可自定义策略模型
- 有两个默认的分配策略
  - `Range`
    - 将主题的若干个连续的分区分配给消费者
    - 分配方式：在每个主题内独立完成的
  - `RoundRobin`
    - 将主题的所有分区逐个分配给消费者
    - 分配方式：将订阅的主题分区全部收集到一起，按轮询顺序方式逐一分配

#### `client.id`

- 该属性可以是任意字符串，broker 用它来标识从客户端发送过来的消息，通常被用在日志、度量指标和配额中

#### `max.poll.records`

- 用于控制单次调用 `call()` 方法能够返回的记录数量
- 可以控制在轮询里需要处理的数据量

#### `receive.buffer.bytes` 和 `send.buffer.bytes`

- 分别指定了 TCP socket 接收和发送数据包的缓冲区大小
- 如果将参数值设置为 `-1`，就使用操作系统的默认值
- 如果生产者或消费者与 broker 处于不同的数据中心，那么可以适当增大这些值，因为跨数据中心的网络一般都有比较高的延迟和比较低的带宽

# 3. 偏移量问题

## 3.1 消息的提交

> 每次调用 poll() 方法，总是返回由生产者写入 Kafka 但还没有被消费者读取过的记录。

- 消费者可通过 Kakfa 来追踪消息在分区里的位置（偏移量），将更新分区当前位置的操作叫做 —— <b style="color:#ff0000">提交</b>

- :thinking: 消费者如何提交偏移量？

  - 消费者往一个叫 `__consumer_offset` 的特殊主题发送消息，消息里包含每个分区的偏移量。
  - 如果消费者一直处于运行状态，那么偏移量将变得没有用处
  - 如果消费者发生崩溃或者有新的消费者加入群组，就会触发再均衡，完成再均衡之后，每个消费者可能分配到新的分区。此时，为了能够继续之前的工作，每个消费者都需要读取每个分区的最后一次提交的偏移量，这时偏移量就变得十分重要了

- 偏移量提交错误，带来的两种影响：

  - 提交的偏移量小于客户端处理的最后一个消息的偏移量，将重复消费消息

    ![偏移量问题-重复消费](http://witty-hamster.gitee.io/draw-bed/Kafka/偏移量问题-重复消费.png)

  - 提交的偏移量大于客户端处理的最后一个消息的偏移量，将丢失消息

    ![偏移量问题-丢失消息](http://witty-hamster.gitee.io/draw-bed/Kafka/偏移量问题-丢失消息.png)

> KafkaConsumer API 提供多种方式来提交偏移量，参考如下部分：

## 3.2 自动提交

> 最简单的提交方式

- 将 `enable.auto.commit` 属性设置为 true，那么每过 5s，消费者会自动把从 poll() 方法接收到的最大偏移量提交上去。
- 自动提交时间间隔由 `auto.commit.interval.ms` 控制，默认为 5s
- 工作机制
  - 自动提交的过程是发生在轮询中的，消费者每次在进行轮询时会检查是否该提交偏移量了，如果是，那么就会提交从上一次轮询返回的偏移量
- 带来的影响
  - 会造成消息被重复消费

## 3.3 提交当前偏移量

- 将 `enable.auto.commit` 设置为 false，使用 `commitSync()` 方法提交偏移量，偏移量提交成功将马上返回，如果提交失败则抛出异常

- 注意：`commitSync()` 将会提交由 `poll()` 返回的最新偏移量，所以在处理完所有记录后要确保调用了 `commitSync()`，否则还是会有丢失消息的风险

- 示例代码

  ```java
  package com.hamster.kafka.consumer.receive;
  
  import com.hamster.kafka.consumer.NewConsumer;
  import lombok.extern.slf4j.Slf4j;
  import org.apache.kafka.clients.consumer.CommitFailedException;
  import org.apache.kafka.clients.consumer.ConsumerRecord;
  import org.apache.kafka.clients.consumer.ConsumerRecords;
  import org.apache.kafka.clients.consumer.KafkaConsumer;
  
  import java.time.Duration;
  import java.util.Collections;
  import java.util.HashMap;
  import java.util.concurrent.TimeUnit;
  
  /**
   * <p>
   *     手动提交当前偏移量
   * </p>
   *
   * @author hamster
   * @date 2022/1/19 下午3:18
   */
  @Slf4j
  public class CommitCurrentOffset {
  
      public static void main(String[] args) {
          HashMap<String, String> propMap = new HashMap<>();
          // 关闭自动提交偏移量
          propMap.put("enable.auto.commit", "false");
          KafkaConsumer<String, String> consumer = NewConsumer.builder("test-group", propMap);
  
          // 订阅消费主题(订阅一个单一主题)
          consumer.subscribe(Collections.singletonList("test"));
          try {
              // 轮询消费
              while (true) {
                  /*
                   *【重要】消费者持续对Kafka进行轮询，否则会被认为消费者已经死亡
                   *  - poll() 方法的参数是一个超时时间，用于控制 poll() 方法的阻塞时间（在消费者的缓存区里没有可用数据时会发生阻塞）
                   *  - 如果该参数设置为 0，poll() 会立即返回，否则它会在指定的毫秒内一直等待 broker 返回数据
                   */
                  ConsumerRecords<String, String> records = consumer.poll(Duration.ofMillis(100));
                  /*
                   * poll() 方法返回一个消息记录列表
                   *  每条记录都包含了记录所属的主题、所属分区、分区中的偏移量、键值对
                   */
                  for (ConsumerRecord<String, String> record : records) {
                      // TODO: 消息消费业务逻辑
                      log.info("record =>> topic = {}, partition = {}, offset = {}, customer = {}, country = {}",
                              record.topic(), record.partition(), record.offset(), record.key(), record.value());
                  }
  
                  TimeUnit.SECONDS.sleep(10);
  
                  try {
                    	// 【注意】这里就是手动提交当前偏移量的代码
                      // 手动提交当前的偏移量，避免重复消费
                      consumer.commitSync();
                  } catch (CommitFailedException e) {
                      // 提交偏移量时，产生异常情况
                      e.printStackTrace();
                  }
              }
          } catch (Exception e) {
              e.printStackTrace();
          } finally {
              /* 主动关闭消费者资源，可以立即触发一次再均衡，避免整个群组在一段时间内无法读取消息 */
              consumer.close();
          }
      }
  }
  
  ```

## 3.4 异步提交

> 手动提交偏移量有一个不足之处，在偏移量提交之前，应用程序会一直阻塞，导致应用程序的吞吐量降低

- 异步提交偏移量，我们尽管发送提交偏移量的请求，而无需等待 broker 的回应

- 示例代码

  ```java
  package com.hamster.kafka.consumer.receive;
  
  import com.hamster.kafka.consumer.NewConsumer;
  import lombok.extern.slf4j.Slf4j;
  import org.apache.kafka.clients.consumer.ConsumerRecord;
  import org.apache.kafka.clients.consumer.ConsumerRecords;
  import org.apache.kafka.clients.consumer.KafkaConsumer;
  
  import java.time.Duration;
  import java.util.Collections;
  import java.util.HashMap;
  import java.util.concurrent.TimeUnit;
  
  /**
   * <p>
   *     异步提交偏移量
   * </p>
   *
   * @author hamster
   * @date 2022/1/19 下午3:44
   */
  @Slf4j
  public class AsyncCommitOffset {
  
      public static void main(String[] args) {
          HashMap<String, String> propMap = new HashMap<>();
          // 关闭自动提交偏移量
          propMap.put("enable.auto.commit", "false");
          KafkaConsumer<String, String> consumer = NewConsumer.builder("test-group", propMap);
  
          // 订阅消费主题(订阅一个单一主题)
          consumer.subscribe(Collections.singletonList("test"));
          try {
              // 轮询消费
              while (true) {
                  /*
                   *【重要】消费者持续对Kafka进行轮询，否则会被认为消费者已经死亡
                   *  - poll() 方法的参数是一个超时时间，用于控制 poll() 方法的阻塞时间（在消费者的缓存区里没有可用数据时会发生阻塞）
                   *  - 如果该参数设置为 0，poll() 会立即返回，否则它会在指定的毫秒内一直等待 broker 返回数据
                   */
                  ConsumerRecords<String, String> records = consumer.poll(Duration.ofMillis(100));
                  /*
                   * poll() 方法返回一个消息记录列表
                   *  每条记录都包含了记录所属的主题、所属分区、分区中的偏移量、键值对
                   */
                  for (ConsumerRecord<String, String> record : records) {
                      // TODO: 消息消费业务逻辑
                      log.info("record =>> topic = {}, partition = {}, offset = {}, customer = {}, country = {}",
                              record.topic(), record.partition(), record.offset(), record.key(), record.value());
                  }
  
                  TimeUnit.SECONDS.sleep(10);
                	// 【注意】这里就是异步提交当前偏移量的代码
                	// 异步提交当前的偏移量
                  consumer.commitAsync(new OffsetCommitCallback() {
                      @Override
                      public void onComplete(Map<TopicPartition, OffsetAndMetadata> offsets, Exception exception) {
                          // TODO: broker作出响应时会执行的回调函数内容，可用于记录错误信息、生成指标信息等
                          if (exception != null) {
                              log.error("Commit failed for offsets {}", offsets, exception);
                          }
                      }
                  });
              }
          } catch (Exception e) {
              e.printStackTrace();
          } finally {
              /* 主动关闭消费者资源，可以立即触发一次再均衡，避免整个群组在一段时间内无法读取消息 */
              consumer.close();
          }
      }
  }
  
  ```

- 在成功提交或者碰到无法恢复的错误之前，`commitSync()` 会一直重试，但是 `commitAsync()` 不会。

- `commitAsync()` 支持回调，在broker做出响应时会执行回调。回调经常被用于记录提交错误或者生成度量指标。

  - 如果要使用回调函数来做偏移量提交重试机制，一定要注意提交的先后顺序，如果无法保证偏移量重试提交的先后顺序，将会导致消息被重复消费的问题。

## 3.5 同步和异步组合提交

> 一般在消费者关闭之前，会组合使用 `commitAsync()` 和 `commitSync()`。确保最后一次的偏移量可以成功提交。

- 示例代码

  ```java
  package com.hamster.kafka.consumer.receive;
  
  import com.hamster.kafka.consumer.NewConsumer;
  import lombok.extern.slf4j.Slf4j;
  import org.apache.kafka.clients.consumer.*;
  import org.apache.kafka.common.TopicPartition;
  
  import java.time.Duration;
  import java.util.Collections;
  import java.util.HashMap;
  import java.util.Map;
  import java.util.concurrent.TimeUnit;
  
  /**
   * <p>
   *     确保最后一次提交偏移量
   * </p>
   *
   * @author hamster
   * @date 2022/1/19 下午4:07
   */
  @Slf4j
  public class LastCommitOffset {
      public static void main(String[] args) {
          HashMap<String, String> propMap = new HashMap<>();
          // 关闭自动提交偏移量
          propMap.put("enable.auto.commit", "false");
          KafkaConsumer<String, String> consumer = NewConsumer.builder("test-group", propMap);
  
          // 订阅消费主题(订阅一个单一主题)
          consumer.subscribe(Collections.singletonList("test"));
          try {
              // 轮询消费
              while (true) {
                  /*
                   *【重要】消费者持续对Kafka进行轮询，否则会被认为消费者已经死亡
                   *  - poll() 方法的参数是一个超时时间，用于控制 poll() 方法的阻塞时间（在消费者的缓存区里没有可用数据时会发生阻塞）
                   *  - 如果该参数设置为 0，poll() 会立即返回，否则它会在指定的毫秒内一直等待 broker 返回数据
                   */
                  ConsumerRecords<String, String> records = consumer.poll(Duration.ofMillis(100));
                  /*
                   * poll() 方法返回一个消息记录列表
                   *  每条记录都包含了记录所属的主题、所属分区、分区中的偏移量、键值对
                   */
                  for (ConsumerRecord<String, String> record : records) {
                      // TODO: 消息消费业务逻辑
                      log.info("record =>> topic = {}, partition = {}, offset = {}, customer = {}, country = {}",
                              record.topic(), record.partition(), record.offset(), record.key(), record.value());
                  }
  
                  TimeUnit.SECONDS.sleep(10);
  
                  // 异步提交当前的偏移量
                  consumer.commitAsync(new OffsetCommitCallback() {
                      @Override
                      public void onComplete(Map<TopicPartition, OffsetAndMetadata> offsets, Exception exception) {
                          // TODO: broker作出响应时会执行的回调函数内容，可用于记录错误信息、生成指标信息等
                          if (exception != null) {
                              log.error("Commit failed for offsets {}", offsets, exception);
                          }
                      }
                  });
              }
          } catch (Exception e) {
              e.printStackTrace();
          } finally {
              try {
                  // 确保消费者在关闭之前，将最后一次的偏移量成功提交到 broker
                  consumer.commitSync();
              } finally {
                  /* 主动关闭消费者资源，可以立即触发一次再均衡，避免整个群组在一段时间内无法读取消息 */
                  consumer.close();
              }
          }
      }
  }
  
  ```

- 如果一切正常，将会使用 `commitAsync()` 来异步的提交偏移量，保证提交速度。

- 如果发生异常，导致消费者被关闭，则在关闭之前使用 `commitSync()` 同步提交偏移量。

## 3.6 提交特定的偏移量

> 如何在批次中间提交偏移量？如何更加频繁的提交偏移量？

- 可以在 `commitSync()` 或 `commitAsync()` 方法中

- 示例代码

  ```java
  package com.hamster.kafka.consumer.receive;
  
  import com.hamster.kafka.consumer.NewConsumer;
  import lombok.extern.slf4j.Slf4j;
  import org.apache.kafka.clients.consumer.*;
  import org.apache.kafka.common.TopicPartition;
  
  import java.time.Duration;
  import java.util.Collections;
  import java.util.HashMap;
  import java.util.Map;
  import java.util.concurrent.TimeUnit;
  import java.util.concurrent.atomic.AtomicInteger;
  
  /**
   * <p>
   *     提交指定的偏移量
   * </p>
   *
   * @author hamster
   * @date 2022/1/19 下午4:14
   */
  @Slf4j
  public class SpecificCommitOffset {
  
      /** 用于跟踪偏移量，按照每个分区跟踪 */
      private static final Map<TopicPartition, OffsetAndMetadata> currentOffsets = new HashMap<>();
      /** 何时进行提交？ */
      private static AtomicInteger count = new AtomicInteger(0);
  
      public static void main(String[] args) {
          HashMap<String, String> propMap = new HashMap<>();
          // 关闭自动提交偏移量
          propMap.put("enable.auto.commit", "false");
          KafkaConsumer<String, String> consumer = NewConsumer.builder("test-group", propMap);
  
          // 订阅消费主题(订阅一个单一主题)
          consumer.subscribe(Collections.singletonList("test"));
          try {
              // 轮询消费
              while (true) {
                  /*
                   *【重要】消费者持续对Kafka进行轮询，否则会被认为消费者已经死亡
                   *  - poll() 方法的参数是一个超时时间，用于控制 poll() 方法的阻塞时间（在消费者的缓存区里没有可用数据时会发生阻塞）
                   *  - 如果该参数设置为 0，poll() 会立即返回，否则它会在指定的毫秒内一直等待 broker 返回数据
                   */
                  ConsumerRecords<String, String> records = consumer.poll(Duration.ofMillis(100));
                  /*
                   * poll() 方法返回一个消息记录列表
                   *  每条记录都包含了记录所属的主题、所属分区、分区中的偏移量、键值对
                   */
                  for (ConsumerRecord<String, String> record : records) {
                      // TODO: 消息消费业务逻辑
                      log.info("record =>> topic = {}, partition = {}, offset = {}, customer = {}, country = {}",
                              record.topic(), record.partition(), record.offset(), record.key(), record.value());
                      // 记录每个分区的最后偏移量 -> 在读取每条记录之后，将期望的偏移量后移一位，偏移量累加 1
                      currentOffsets.put(new TopicPartition(record.topic(), record.partition()),
                              new OffsetAndMetadata(record.offset() + 1, "no metadata"));
                      // 这里，对每处理1000条记录就提交一次偏移量。可根据实际情况修改
                      if (count.getAndIncrement() % 1000 == 0) {
                          // 提交偏移量时，指明当前要提交哪个分区的偏移量 currentOffsets
                          consumer.commitAsync(currentOffsets, new OffsetCommitCallback() {
                              @Override
                              public void onComplete(Map<TopicPartition, OffsetAndMetadata> offsets, Exception exception) {
                                  // TODO: broker作出响应时会执行的回调函数内容，可用于记录错误信息、生成指标信息等
                                  if (exception != null) {
                                      log.error("Commit failed for offsets {}", offsets, exception);
                                  }
                              }
                          });
                      }
                  }
  
                  TimeUnit.SECONDS.sleep(10);
              }
          } catch (Exception e) {
              e.printStackTrace();
          } finally {
              try {
                  // 确保消费者在关闭之前，将最后一次的偏移量成功提交到 broker
                  consumer.commitSync();
              } finally {
                  /* 主动关闭消费者资源，可以立即触发一次再均衡，避免整个群组在一段时间内无法读取消息 */
                  consumer.close();
              }
          }
      }
  }
  
  ```

# 4. 再均衡监听器

> 参考：`ConsumerRebalanceListener` 接口

- 使用方式：在调用 `subscribe()` 方法订阅主题时，传入一个 `ConsumerRebalanceListener` 实现即可

- 两个必要的实现方法

  - `void onPartitionsRevoked(Collection<TopicPartition> partitions);`
    - 再均衡开始之前和消费者停止读取消息之后被调用。如果在这里提交偏移量，下一个接管分区的消费者就知道该从哪里开始读取了
  - `void onPartitionsAssigned(Collection<TopicPartition> partitions);`
    - 在重新分配分区之后和消费者开始读取消息之前被调用

- 示例代码

  ```java
  package com.hamster.kafka.rebalance;
  
  import lombok.extern.slf4j.Slf4j;
  import org.apache.kafka.clients.consumer.ConsumerRebalanceListener;
  import org.apache.kafka.common.TopicPartition;
  
  import java.util.Collection;
  
  /**
   * <p>
   *     自定义再均衡监听器
   * </p>
   *
   * @author hamster
   * @date 2022/1/19 下午4:41
   */
  @Slf4j
  public class HandleRebalanceListener implements ConsumerRebalanceListener {
  
      /**
       * 再均衡开始之前和消费者停止读取消息之后被调用
       * @param partitions
       */
      @Override
      public void onPartitionsRevoked(Collection<TopicPartition> partitions) {
          log.info("Lost partitions in rebalance. Committing offsets");
      }
  
      /**
       * 在重新分配分区之后和消费者开始读取消息之前被调用
       * @param partitions
       */
      @Override
      public void onPartitionsAssigned(Collection<TopicPartition> partitions) {
  
      }
  }
  
  ```

# 5. 从特定位置消费消息

- `seekToBeginning(Collection<TopicPartition> tp)` ：从分区的起始位置开始读取消息
- `seekToEnd(Collection<TopicPartition> tp)`：从分区末尾开始读取消息

## 5.1 :thinking: 思考：如果偏移量保存在数据库而不是Kafka里，那么消费者在得到新分区时怎么知道该从哪里开始读取？

- 可以使用 `seek()` 方法

- 在消费者启动或分配到新分区时，可以使用 `seek()` 方法查找保存在数据库里的偏移量

- 通过 `ConsumerRebalanceListener` 实现和 `seek()` 方法搭配的方式，实现偏移量的存储以及指定位置的消息读取

- 示例代码

  ```java
  package com.hamster.kafka.consumer.receive;
  
  import com.hamster.kafka.consumer.NewConsumer;
  import org.apache.kafka.clients.consumer.ConsumerRebalanceListener;
  import org.apache.kafka.clients.consumer.ConsumerRecord;
  import org.apache.kafka.clients.consumer.ConsumerRecords;
  import org.apache.kafka.clients.consumer.KafkaConsumer;
  import org.apache.kafka.common.TopicPartition;
  
  import java.time.Duration;
  import java.util.Collection;
  import java.util.Collections;
  import java.util.HashMap;
  import java.util.Map;
  
  /**
   * <p>
   *     指定位置消费消息
   * </p>
   *
   * @author hamster
   * @date 2022/1/19 下午5:20
   */
  public class SpecifyLocationConsumer {
  
      static class SaveOffsetsOnRebalance implements ConsumerRebalanceListener {
  
          private KafkaConsumer<String, String> consumer;
  
          public SaveOffsetsOnRebalance(KafkaConsumer<String, String> consumer) {
              this.consumer = consumer;
          }
  
          @Override
          public void onPartitionsRevoked(Collection<TopicPartition> partitions) {
              // 提交偏移量到DB数据库，事务管理，保证事务原子性，数据不重复不丢失
              commitDBTransaction();
          }
  
          @Override
          public void onPartitionsAssigned(Collection<TopicPartition> partitions) {
              for (TopicPartition partition : partitions) {
                  consumer.seek(partition, getOffsetFormDB(partition));
              }
          }
  
          /**
           * 通过主题分区信息，获取DB中存储的对应偏移量
           * @param partition
           * @return
           */
          public int getOffsetFormDB(TopicPartition partition) {
              return 0;
          }
  
          /**
           * 将主题的每个分区的偏移量提交到DB
           *  在同一个事务中，保存事件的原子性，从而保证数据不重复、不丢失
           */
          public void commitDBTransaction() {
          }
      }
  
      public static void main(String[] args) {
          Map<String, String> propMap = new HashMap<>();
          propMap.put("enable.auto.commit", "false");
          KafkaConsumer<String, String> consumer = NewConsumer.builder("test-group", propMap);
  
          SaveOffsetsOnRebalance saveOffsetsOnRebalance = new SaveOffsetsOnRebalance(consumer);
          // 指定再均衡监听器
          consumer.subscribe(Collections.singletonList("test"), saveOffsetsOnRebalance);
          consumer.poll(Duration.ZERO);
  
          for (TopicPartition partition : consumer.assignment()) {
              /*
               * 订阅主题之后，开始开启消费，先调用一次 poll() 方法，让消费者加入到消费者群组中，并获取分配的分区，然后马上调用 seek() 方法定位分区的偏移量。
               * 切记：seek()方法只更新我们正在使用的位置，在下一次调用 poll() 是就可以获取到正确的消息。
               *      如果 seek()发生错误，poll()就会抛出异常
               */
              consumer.seek(partition, saveOffsetsOnRebalance.getOffsetFormDB(partition));
          }
          while (true) {
              ConsumerRecords<String, String> records = consumer.poll(Duration.ofMillis(100));
              for (ConsumerRecord<String, String> record : records) {
                  // 记录记录
                  // processRecord(record);
                  // 存储记录到DB
                  // storeRecordInDB(record);
                  // 记录偏移量到DB
                  // storeOffsetInDB(record);
              }
              saveOffsetsOnRebalance.commitDBTransaction();
          }
      }
  }
  
  ```

# 6. 如何优雅的结束消费者拉取消息

- `consumer.wakeup()` 方法
  - 跳出 poll() 循环最安全的方法
  - 该方法可以通过另一个线程，安全的调用。可以退出消费者的 poll()，并抛出一个 `WakeupException` 异常。该异常我们不需要额外处理，这只是一个用于跳出循环的一种方式。
- 注意：在跳出循环后，一定要执行 `consumer.close()` 方法。

# 7. 反序列化器

- 自定义反序列化器

  ```java
  package com.hamster.kafka.serialization;
  
  import com.hamster.kafka.serialization.pojo.Customer;
  import org.apache.kafka.common.errors.SerializationException;
  import org.apache.kafka.common.header.Headers;
  import org.apache.kafka.common.serialization.Deserializer;
  
  import java.io.UnsupportedEncodingException;
  import java.nio.ByteBuffer;
  import java.util.Map;
  
  /**
   * <p>
   *     自定义反序列化器
   * </p>
   *
   * @author hamster
   * @date 2022/1/19 下午5:58
   */
  public class CustomerDeserializer implements Deserializer<Customer> {
  
      @Override
      public void configure(Map<String, ?> configs, boolean isKey) {
          // TODO: 额外的配置项
      }
  
      @Override
      public Customer deserialize(String topic, byte[] data) {
          int id;
          int nameSize;
          String name;
  
          try {
              if (data == null) {
                  return null;
              }
              if (data.length < 8) {
                  throw new SerializationException("Size of data received by IntegerDeserializer is shorter than expected");
              }
              ByteBuffer buffer = ByteBuffer.wrap(data);
              id = buffer.getInt();
              nameSize = buffer.getInt();
  
              byte[] nameBytes = new byte[nameSize];
              buffer.get(nameBytes);
              name = new String(nameBytes, "UTF-8");
  
              return new Customer(id, name);
          } catch (UnsupportedEncodingException e) {
              throw new SerializationException("Error when serializing Customer to byte[] " + e);
          }
      }
  
      @Override
      public Customer deserialize(String topic, Headers headers, byte[] data) {
          return null;
      }
  
      @Override
      public void close() {
          // 无需关闭任何资源
      }
  }
  
  ```

- 使用 Apache Avro 反序列化框架

# 8. 独立消费者

> 消费者不需要加入任何群组中，不需要订阅主题，而是为自己分配分区

- 注意：
  - 独立消费者不会发生再均衡，不需要手动查找分区
  - 如果增加新分区，消费者并不会收到通知。如何解决不会收到通知问题？
    - 方案一：周期性的调用 `partitionsFor()` 方法，检查是否有新的分区加入
    - 方案二：重启应用程序

- 示例代码

  ```java
  package com.hamster.kafka.consumer.receive;
  
  import com.hamster.kafka.consumer.NewConsumer;
  import org.apache.kafka.clients.consumer.ConsumerRecord;
  import org.apache.kafka.clients.consumer.ConsumerRecords;
  import org.apache.kafka.clients.consumer.KafkaConsumer;
  import org.apache.kafka.common.PartitionInfo;
  import org.apache.kafka.common.TopicPartition;
  
  import java.time.Duration;
  import java.util.ArrayList;
  import java.util.List;
  
  /**
   * <p>
   *     独立的消费者，无消费者群组概念
   * </p>
   *
   * @author hamster
   * @date 2022/1/19 下午6:11
   */
  public class SingleConsumer {
  
      public static void main(String[] args) {
          KafkaConsumer<String, String> consumer = NewConsumer.builder();
  
          // 配置分区
          List<PartitionInfo> partitionInfoList = null;
          // 从哪个主题来读取可用的分区。如果只读取特定的分区，可以跳过这一步
          partitionInfoList = consumer.partitionsFor("test");
  
          if (partitionInfoList != null) {
              List<TopicPartition> partitions = new ArrayList<>();
              for (PartitionInfo partition : partitionInfoList) {
                  partitions.add(new TopicPartition(partition.topic(), partition.partition()));
              }
              // 知道需要哪些分区之后，调用 assign()方法
              consumer.assign(partitions);
  
              while (true) {
                  ConsumerRecords<String, String> records = consumer.poll(Duration.ofMillis(100));
                  for (ConsumerRecord<String, String> record : records) {
                      System.err.printf("topic = %s, partition = %s, offset = %d, customer = %s, country = %s\n",
                              record.topic(), record.partition(), record.offset(), record.key(), record.value());
                  }
                  consumer.commitSync();
              }
          }
      }
  }
  
  ```

  

# :boom:  TIPS

## 1. 提交偏移量异步重试解决方案

- 可以在异步回调函数中，使用一个单调递增的序列号来维护异步提交的顺序。在每次提交偏移量之后或者在回调里提交偏移量时递增序列号。
- 在进行重试之前，先检查回调的序列号和即将提交的偏移量是否相等，如果相等，说明没有新的提交，那么可以安全的进行重试。如果序列号比较大，说明有一个新的提交已经发送出去了，应该停止重试。









































