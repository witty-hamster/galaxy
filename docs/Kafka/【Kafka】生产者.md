[TOC]

> 写数据到 Kafka
>
> :star2: 考虑的问题
>
> 	1. 是否每个消息都很重要？
> 	1. 是否允许丢失一小部分消息？
> 	1. 偶尔出现重复消息是否可以接受？
> 	1. 是否有严格的延迟和吞吐量要求？

# 1. 消息发送过程

- 主要步骤示例图

​	![生产者-生产者组件图](http://witty-hamster.gitee.io/draw-bed/Kafka/生产者-生产者组件图.png)

- 消息发送步骤（从创建一个 ProducerRecord 对象开始）
  1. ProducerRecord 对象需要包含目标主题和要发送的内容，可以指定键或分区
  2. 在发送 ProducerRecord 对象时，生产者要先把键和值对象序列化成字节数组，只有序列化后才能在网络上传输
  3. 数据将被传给分区器，如果在 ProducerRecord 对象中指定了分区，那么分区器就不会再做任何操作，直接把消息的分区返回。如果没有指定分区，那么分区器会根据 ProducerRecord 对象的键来选择一个分区
  4. 分区指定后，生产者就知道该往哪个主题和分区发送记录了
  5. 发送消息后，消息记录将被添加到一个记录批次里，这个批次里的所有消息会被发送到相同的主题和分区上。通过一个独立的线程负责把这些记录批次发送到对应的broker上，进行落盘
  6. 服务器接收到这些消息后，会给出一个响应。
     - 如果成功写入 Kafka，就返回一个 RecordMetaData 对象（元对象），它包含了消息的主题和分区信息，以及记录了消息在分区里的偏移量
     - 如果写入失败，则会返回一个错误。生产者在接收到错误之后，会尝试重试发送消息。如果一直还是失败，则返回错误信息。

# 2. 生产者关键性配置属性

> 在内存使用、性能和可靠性方面，对生产者影响比较大

## `bootstrap.servers`

- 该属性指定 broker 的地址清单，地址的格式为 `host:port`
- 未必需要将所有的 broker 地址全部配置到该配置项中，生产者可以通过给定的 broker 中查找到其他 broker 信息
- 建议：至少给定两个 broker 信息，避免服务宕机

## `key.serializer`

- 必须要设置的，使用指定的类将键序列化
- 由于 broker 仅接收字节数组类型的键与值。生产者可通过 `key.serializer` 所设置的序列化类型，将对象序列化为字节数组
- 默认提供的序列化方式
  - ByteArraySerializer
  - StringSerializer：字符串类型
  - IntegerSerializer：整数类型

## `value.serializer`

- 必须要设置的，使用指定的类将值序列化
- 默认提供的序列化方式与 `key.serializer` 一致

## `acks`

- 指定了必须要有多少个分区副本收到消息，生产者才会认为消息写入是成功的

- 该参数的三种不同指标
  - `acks = 0`
    - 生产者在成功写入消息之前不会等待任何来自服务器的响应。
    - 如果消息传输中，出现了问题，导致服务器没有收到消息，那么生产者就无从得知，消息也就丢失了
    - 优点：生产者不需要等待服务器的响应，可以以网络能够支持的最大速度发送消息，到达很高的吞吐量
  - `acks = 1`
    - 只要集群的首领节点收到信息，生产者就会收到一个来自服务器的成功响应。
    - 如果消息无法到达首领节点（比如首领节点崩溃，新的首领节点还没有选举出来），生产者会收到一个错误响应，为了避免数据丢失，生产者会重新发送消息
    - 如果一个没有收到消息的节点成为新首领，消息还是会丢失。
    - 该模式下，吞吐量的大小取决于 ***同步发送消息*** 还是 ***异步发送消息***
  - `acks = all`
    - 只有当所有参与复制的节点全部收到消息时，生产者才会收到一个来自服务器的成功响应
    - 这个模式是最安全的，但它的吞吐量更低，延迟更高

## `buffer.memory`

- 用来设置生产者内存缓冲区的大小
- 生产者用它缓冲要发送到服务器的消息
- 如果应用程序发送消息的速度超过发送到服务器的速度，会导致生产者空间不足。此时，send() 方法调用要么被阻塞，要么抛出异常，取决于如何设置 `block.on.buffer.full` 参数（在 0.9.0.0 版本中被替换为 `max.block.ms`，表示在抛出异常之前可以阻塞一段时间）

## `compression.type`

- 设置消息压缩类型，使用压缩可以降低网络传输开销和存储开销
- 默认情况下，消息发送时不会被压缩
- 三种压缩算法
  - `snappy` 压缩算法
    - 由 Google 发明，占用较少的 CPU，能提供较好的性能和相当可观的压缩比
  - `gzip` 压缩算法
    - 一般会占用较多 CPU，但会提供更高的压缩比
  - `lz4` 压缩算法

## `retries`

- 决定了生产者可以重发消息的次数，如果到达了所设置的值，生产者会放弃重试并返回错误。
- 默认情况下，生产者会在每次重试之间等待 100ms（可通过 `retry.backoff.ms` 参数来改变这个时间间隔）

## `batch.size`

- 指定了一个批次可以使用的内存大小，按照字节数计算（并非消息个数）。
- 生产者不一定会等到批次填满后才发送，有可能当前批次是个半满状态，也可能当前批次中仅有一个消息。合理的设置批次大小，可以减少资源的开销

## `linger.ms`

- 指定了生产者在发送批次之前等待更多消息加入批次的时间。
- 生产者会在批次填满或 `linger.ms` 达到上限时把批次发送出去。

## `client.id`

- 该参数可以是任意的字符串，服务器用它来识别消息的来源，还可以用在日志和配额指标里

## `max.in.flight.requests.per.connection`

- 指定了生产者在收到服务器响应之前可以发送多少个消息
- 该参数值越高，占用的内存越多，但也会提升吞吐量
- 将其设置为 `1` 可以保证消息是按照发送的顺序写入服务器的，即使发生了重试

## `timeout.ms`、`request.timeout.ms` 和 `metadata.fetch.timeout.ms`

- `request.timeout.ms`
  - 指定了生产者在发送数据时等待服务器返回响应的时间
- `metadata.fetch.timeout.ms`
  - 指定了生产者在获取元数据时等待服务器返回响应的时间
- 如果等待响应超时，那么生产者要么重试，要么返回一个错误
- `timeout.ms`
  - 指定了 broker 等待同步副本返回消息确认的时间，与 `acks` 的配置相匹配 —— 如果在指定时间内没有收到同步副本的确认，那么 broker 就会返回一个错误

## `max.block.ms`

- 指定了在调用 `send()` 方法或使用 `partitionsFor()` 方法获取元数据时生产者的阻塞时间
- 当生产者的发送缓冲区已满，或没有可用的元数据时，这些方法就会被阻塞。阻塞到达所设置的上限时，生产者就会抛出超时异常

## `max.request.size`

- 用于控制生产者发送的请求大小（可以指能发送的单个消息的最大值，也可以指单个请求里所有消息总的大小）
- 注意：当前参数的设置要与 `message.max.bytes`（broker的配置项） 所设置的值匹配，避免生产者发送的消息被 broker 拒绝

## `receive.buffer.bytes` 和 `send.buffer.bytes`

- 分别指定了 TCP socket 接收和发送数据包的缓冲区大小
- 如果将参数值设置为 `-1`，就使用操作系统的默认值
- 如果生产者或消费者与 broker 处于不同的数据中心，那么可以适当增大这些值，因为跨数据中心的网络一般都有比较高的延迟和比较低的带宽

# 3. 发送消息的三种模式

## 3.1 发送并忘记（fire-and-forget）

> 只管往服务器发送消息，而并不关系是否可以正常到达。
>
> 该种模式下，有可能产生消息丢失

- 直接调用 KafkaProducer 类中的 send() 方法

## 3.2 同步发送

> 通过 `send()` 方法发送消息，返回一个 `Future` 对象，调用 `get()` 方法等待消息是否发送成功。

- 调用 KafkaProducer 类中的 send() 方法，使用调用链模式，再调用 get() 方法

## 3.3 异步发送

> 调用 `send()` 方法，并指定一个回调函数，服务器在返回响应是调用回调函数。

- 调用 KafkaProducer 类中的 send() 的重构方法，方法的第二个参数为回调函数 Callback 类

# 4. 序列化器

## 4.1 默认的序列化器

> Kafka 提供多种序列化器，可参考 org.apache.kafka.common.serialization 包下的类

- 常用的序列化器：仅针对简单的字符串类型、整数类型、字节类型对象提供序列化操作
  - `StringSerializer`：字符串序列化器
  - `IntegerSerializer`：整数序列化器
  - `ByteArraySerializer`：字节数组序列化器

## 4.2 自定义序列化器

- 示例

  ```java
  package com.hamster.kafka.serialization;
  
  import com.hamster.kafka.serialization.pojo.Customer;
  import org.apache.kafka.common.errors.SerializationException;
  import org.apache.kafka.common.header.Headers;
  import org.apache.kafka.common.serialization.Serializer;
  
  import java.nio.ByteBuffer;
  import java.util.Map;
  
  /**
   * <p>
   *     自定义序列化器
   * </p>
   *
   * @author hamster
   * @date 2022/1/18 下午3:16
   */
  public class CustomerSerializer implements Serializer<Customer> {
  
      /**
       * 序列化核心方法
       *  Customer 对象序列化成：
       *      - 表示 customerId 的 4字节整数
       *      - stringSize 表示 customerName 长度的 4字节整数（如果 customerName为空，则长度为 0）
       *      - serializedName 表示 customerName 的 N个字节
       * @param topic
       * @param data
       * @return
       */
      @Override
      public byte[] serialize(String topic, Customer data) {
  
          try {
              byte[] serializedName;
              int stringSize;
              if (data == null) {
                  return null;
              } else {
                  if (data.getCustomerName() != null) {
                      serializedName = data.getCustomerName().getBytes("UTF-8");
                      stringSize = serializedName.length;
                  } else {
                      serializedName = new byte[0];
                      stringSize = 0;
                  }
              }
  
              ByteBuffer buffer = ByteBuffer.allocate(4 + 4 + stringSize);
              buffer.putInt(data.getCustomerId());
              buffer.putInt(stringSize);
              buffer.put(serializedName);
              return buffer.array();
          } catch (Exception e) {
              throw new SerializationException("Error when serializing Customer to byte[] " + e);
          }
      }
  
      @Override
      public void configure(Map<String, ?> configs, boolean isKey) {
          // TODO: 可做自定义配置
      }
  
      @Override
      public byte[] serialize(String topic, Headers headers, Customer data) {
          return new byte[0];
      }
  
      @Override
      public void close() {
          // TODO: 不需要关闭任何东西
      }
  }
  
  ```

- 自定义序列化器的劣势

  - 序列化器中的内容需要更具业务情况进行定制化调整
  - 新旧消息的兼容性问题
  - 所有的过程中都需要使用相同的序列化器
  - 如果序列化器发生修改，那么所有与该序列器有连的项目，都需要改动

- 针对自定义序列化器的不稳定因素，建议使用已有的序列化器和反序列化器，比如 JSON、Avro、Thrift 和 Protobuf

## 4.3 Avro 序列化器

> Apache Avro 是一种与编程语言无关的序列化格式，提供一种共享数据文件的方式。

- 原理

  - Avro 数据通过与语言无关的 schema 来定义。schema 通过 JSON 来描述，数据被序列化成二进制文件或 JSON文件，一般使用二进制文件。Avro 在读写文件时需要用到 schema，schema一般会被内嵌在数据文件里。

- 特性

  - 当负责写消息的应用程序使用了新的 schema，负责读消息的应用程序可以继续处理消息而无需做任何改动。

- 需要注意一下两点

  1. 用于写入数据和读取数据的 schema 必须是相互兼容的。
  2. 反序列化器需要用到用于写入数据的 schema，即使它可能与用于读取数据的 schema 不一样。Avro 数据文件里就包含了用于写入数据的 schema。在Kafka里有更好的处理方案。

- 在 Kafka 中使用 Avro序列化器，需要使用到 [Confluent Schema Registry](https://docs.confluent.io/platform/6.2.0/schema-registry/index.html) 注册表，将 Avro 的 schema 信息注册到该注册表中

- Avro 序列化与反序列化的流程图

  ![Avro序列化与反序列化流程图.png](http://witty-hamster.gitee.io/draw-bed/Kafka/Avro序列化与反序列化流程图.png)

- 流程描述

  1. 我们把所有写入数据需要用到的 schema 保存到注册表中
  2. 在记录里引用 schema 的标识符
  3. 负责读取数据的应用程序使用标识符从注册表里拉取 schema 来反序列化记录
  4. 序列化器和反序列化器分别负责处理 schema 的注册和拉取

# 5. 分区

## 5.1 键的两个用途

1. 可以作为消息的附加信息
2. 可以用来决定消息该被写到主题的哪个分区

## 5.2 默认分区特点

- 如果键被设置为 null，并且使用了默认的分区器，那么记录将被随机地发送到主题内各个可用的分区上。分区器使用轮询（Round Robin）算法将消息均衡地分布到各个分区上
- 如果键不为 null，并使用了默认的分区器，那么 Kafka 会对键进行散列（使用 Kafka自己的散列算法，即使升级 Java版本，散列值也不会发生变化），然后根据散列值把消息映射到特定的分区上。
  - 关键点：同一个键总是被映射到同一个分区上，因此在进行映射时，会使用主题所有分区，而不是可用分区。
  - 由于使用主题的所有分区，可能会造成错误的发生。但这种情况比较少见。
- <b style="color:#ff0000">注意：一旦主题创建后，尽量不要修改分区个数。如果想要修改分区个数，那么在一开始时，就需要明确具体的键映射哪个分区。这样才能保证数据完整消费。</b>

## 5.3 实现自定义分区策略

- 示例

  ```java
  package com.hamster.kafka.partitioner;
  
  import org.apache.kafka.clients.producer.Partitioner;
  import org.apache.kafka.common.Cluster;
  import org.apache.kafka.common.InvalidRecordException;
  import org.apache.kafka.common.PartitionInfo;
  import org.apache.kafka.common.utils.Utils;
  
  import java.util.List;
  import java.util.Map;
  
  /**
   * <p>
   *     自定义分区策略
   * </p>
   *
   * @author hamster
   * @date 2022/1/18 下午4:53
   */
  public class CustomerPartitioner implements Partitioner {
  
      /**
       * 核心分区策略方法
       * @param topic 主题
       * @param key 键
       * @param keyBytes 键字节数组
       * @param value 值
       * @param valueBytes 值字节数组
       * @param cluster 集群
       * @return 分区位置
       */
      @Override
      public int partition(String topic, Object key, byte[] keyBytes,
                           Object value, byte[] valueBytes, Cluster cluster) {
          // 通过主题名称，获取分区列表
          List<PartitionInfo> partitions = cluster.partitionsForTopic(topic);
          // 分区个数
          int numPartitions = partitions.size();
  
          if ((keyBytes == null) || (!(key instanceof String))) {
              throw new InvalidRecordException("We expect all messages to have customer name as key");
          }
  
          if ("Banana".equals((String) key)) {
              // 如果是 Banana 供应商key，则直接分配到最后一个分区
              return numPartitions;
          }
  
          // 其他记录以散列值方式分散到其他分区
          return (Math.abs(Utils.murmur2(keyBytes))) % (numPartitions - 1);
      }
  
      @Override
      public void close() {
          // TODO: 资源关闭方法
      }
  
      @Override
      public void configure(Map<String, ?> configs) {
          // TODO: 额外自定义配置项
      }
  }
  
  ```



# TIPS

## 1. 如何保证消息顺序性

> 前提：仅能保证一个分区里的消息是有序的

- 生产者按照一定顺序发送消息，broker 就会按照这个顺序把它们写入分区，消费者也会按照同样的顺序读取它们。
- 一般来说，对于要求消息有序的场景，消息是否成功写入也很关键，不建议把 `retries` 设置为 0，可以把 `max.in.flight.requests.per.connection` 设置为 1，这样在生产者尝试发送第一批消息时，就不会有其他的消息发送给 broker。不过这样将严重影响生产者的吞吐量，所以只有在对消息的顺序有严格要求的情况下才能这么做。















