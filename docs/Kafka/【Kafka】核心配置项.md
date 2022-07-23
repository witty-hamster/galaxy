[TOC]

> Kafka 核心配置参数

# 1. Kafka Server 核心配置参数

> Server Configs

| property                                     | default | description |
| -------------------------------------------- | ------- | ----------- |
| broker.id                                    |         |             |
| log.dirs                                     |         |             |
| port                                         |         |             |
| zookeeper.connect                            |         |             |
| message.max.bytes                            |         |             |
| num.network.threads                          |         |             |
| num.io.threads                               |         |             |
| background.threads                           |         |             |
| queued.max.requests                          |         |             |
| host.name                                    |         |             |
| advertised.host.name                         |         |             |
| advertised.port                              |         |             |
| scoket.send.buffer.bytes                     |         |             |
| socket.receive.buffer.bytes                  |         |             |
| socket.request.max.bytes                     |         |             |
| num.partitions                               |         |             |
| log.segment.bytes                            |         |             |
| log.roll.hours                               |         |             |
| log.cleanup.policy                           |         |             |
| log.retention.minutes 和 log.retention.hours |         |             |
| log.retention.bytes                          |         |             |
| log.retention.check.interval.ms              |         |             |
| log.cleaner.enable                           |         |             |
| log.cleaner.threads                          |         |             |
| log.cleaner.io.max.bytes.per.second          |         |             |
| log.cleaner.io.buffer.size                   |         |             |
| log.cleaner.io.buffer.load.factor            |         |             |
| log.cleaner.backoff.ms                       |         |             |
| log.cleaner.min.cleanable.ratio              |         |             |
| log.cleaner.delete.retention.ms              |         |             |
| log.index.size.max.bytes                     |         |             |
| log.index.interval.bytes                     |         |             |
| log.flush.interval.messages                  |         |             |
| log.flush.scheduler.interval.ms              |         |             |
| log.flush.interval.ms                        |         |             |
| log.delete.delay.ms                          |         |             |
| auto.create.topics.enable                    |         |             |
| controller.socket.timeout.ms                 |         |             |
| controller.message.queue.size                |         |             |
| default.replication.factor                   |         |             |
| replica.lag.time.max.ms                      |         |             |
| replica.lag.max.message                      |         |             |
| replica.socket.timeout.ms                    |         |             |
| replica.socket.receive.buffer.bytes          |         |             |
| replica.fetch.max.bytes                      |         |             |
| replica.fetch.min.bytes                      |         |             |
|                                              |         |             |



# 2. 生产者核心配置参数

> Producer Configs

- 核心配置项

| name                      | type    | default  | importance  | description                                                  |
| ------------------------- | ------- | -------- | ----------- | ------------------------------------------------------------ |
| bootstrap.servers         | list    |          | :star: high | 用于建立与 kafka 集群连接的 host/port 组。数据将会在所有 servers 上均衡加载，不管哪些server是指定用于bootstrapping。这个列表仅仅影响初始化的 hosts（用于发现全部的 servers）。这个列表格式: host1:port1,host2:port2,... <br/>因为这些 server 仅仅是用于初始化的连接，以发现集群所有成员关系（可能会动态的变化）， 这个列表不需要包含所有的 servers（你可能要不止一个 server，尽管这样，可能某个 server 宕机了）。如果没有 server 在这个列表出现， 则发送数据会一直失败，直到列表可用。 |
| acks                      | string  | 1        | :star: high | producer 需要 server 接收到数据之后发出的确认接收的信号，此项配置就是指 procuder 需要多少个这样的确认信号。此配置实际上代表了数据备份的可用性。以下设置为常用选项：<br/>（1）acks=0：设置为 0 表示 producer 不需要等待任何确认收到的信息。副本将立即加到 socket buffer并认为已经发送。没有任何保障可以保证此种情况下 server 已经成功接收数据，同时重试配置不会发生作用（因为客户端不知道是否失败）回馈的 offset 会总是设置为-1；<br/>（2）acks=1：这意味着至少要等待 leader 已经成功将数据写入本地 log，但是并没有等待所有 follower 是否成功写入。这种情况下，如果 follower 没有成功备份数据，而此时 leader 又挂掉，则消息会丢失；<br/>（3）acks=all：这意味着 leader 需要等待所有备份都成功写入日志，这种策略会保证只要有一个备份存活就不会丢失数据。这是最强的保 证；<br/>（4）其他的设置，例如 acks=2 也是可以的， 这将需要给定的 acks 数量，但是这种策略一般很少用。 |
| buffer.memory             | long    | 33554432 | :star: high | producer 可以用来缓存数据的内存大小。如果数据产生速度大于向 broker 发送的速度， producer 会阻塞或者抛出异常，以 `block.on.buffer.full`来表明。<br/>这项设置将和 producer 能够使用的总内存相关，但并不是一个硬性的限制，因为不是 producer 使用的所有内存都是用于缓存。一些额外的内存会用于压缩（如果引入压缩机制）， 同样还有一些用于维护请求。 |
| compression.type          | string  | none     | :star: high | producer 用于压缩数据的压缩类型。默认是无压缩。正确的选项值是 `none`、`gzip`、`snappy`。 压缩最好用于批量处理，批量处理消息越多，压缩性能越好。 |
| retries                   | int     | 0        | :star: high | 设置大于 0 的值将使客户端重新发送任何数据， 一旦这些数据发送失败。注意，这些重试与客户端接收到发送错误时的重试没有什么不同。允许重试将潜在的改变数据的顺序，如果这两个消息记录都是发送到同一个 partition，则第一个消息失败第二个发送成功，则第二条消息会比第一条消息出现要早。 |
| batch.size                | int     | 16384    | medium      | producer 将试图批处理消息记录，以减少请求次数。这将改善 client 与 server 之间的性能。 这项配置控制默认的批量处理消息字节数。 不会试图处理大于这个字节数的消息字节数。 发送到 brokers 的请求将包含多个批量处理， 其中会包含对每个 partition 的一个请求。 较小的批量处理数值比较少用，并且可能降低吞吐量（0 则会仅用批量处理）。较大的批量处理数值将会浪费更多内存空间，这样就需要分配特 定批量处理数值的内存大小。 |
| client.id                 | string  |          | medium      | 当向 server 发出请求时，这个字符串会发送给 server。目的是能够追踪请求源头，以此来允许 ip/port 许可列表之外的一些应用可以发送信息。这项应用可以设置任意字符串，因为没有任何功能性的目的，除了记录和跟踪 |
| linger.ms                 | long    | 0        | medium      | producer 组将会汇总任何在请求与发送之间到达的消息记录一个单独批量的请求。通常来说，这只有在记录产生速度大于发送速度的时候才能发生。然而，在某些条件下，客户端将希望降低请求的数量，甚至降低到中等负载以下。这项设置将通过增加小的延迟来完成 —— 即，不是立即发送一条记录，producer 将会等待给定的延迟时间以允许其他消息记录发送，这些消息记录可以批量处理。这可以认为是 TCP 中 Nagle 的算法类似。这项设置设定了批量处理的更高的延迟 边界：一旦我们获得某个 partition 的 batch.size，他将会立即发送而不顾这项设置，然而如果我们获得消息字节数比这项设置要小的多，我们需要 `linger` 特定的时间以获取更多的消息。 这个设置默认为 0，即没有延迟。设定 linger.ms=5，例如，将会减少请求数目， 但是同时会增加 5ms 的延迟。 |
| max.request.size          | int     | 1028576  | medium      | 请求的最大字节数。这也是对最大记录尺寸的有效覆盖。注意：server 具有自己对消息记录尺寸的覆盖，这些尺寸和这个设置不同。此项设置将会限制 producer 每次批量发送请求的数目，以防发出巨量的请求。 |
| receive.buffer.bytes      | int     | 32768    | medium      | TCP receive 缓存大小，当阅读数据时使用                       |
| send.buffer.bytes         | int     | 131072   | medium      | TCP send 缓存大小，当发送数据时使用                          |
| timeout.ms                | int     | 30000    | medium      | 此配置选项控制 server 等待来自 followers 的确认的最大时间。如果确认的请求数目在此时间内没有回复，则会返回一个错误。这个超时限制是以 server 端度量的，没有包含请求的网络延迟 |
| block.on.buffer.full      | boolean | true     | low         | 当我们内存缓存用尽时，必须停止接收新消息记录或者抛出错误。默认情况下，这个设置为真， 然而某些阻塞可能不值得期待，因此立即抛出错误更好。设置为 false 则会这样：producer 会抛出一个异常错误: BufferExhaustedException， 如果记录已经发送同时缓存已满 |
| metadata.fetch.timeout.ms | long    | 60000    | low         | 是指我们所获取的一些元素据的第一个时间数据。元素据包含：topic，host，partitions。 此项配置是指当等待元素据 fetch 成功完成所需要的时间，否则会抛出异常给客户端。 |
| metadata.max.age.ms       | long    | 300000   | low         | 以微秒为单位的时间，是在我们强制更新 metadata 的时间间隔。即使我们没有看到任何 partition leadership 改变。 |
| metric.reporters          | list    | []       | low         | 类的列表，用于衡量指标。实现 MetricReporter 接口，将允许增加一些类，这些类在新的衡量指标产生时就会改变。JmxReporter 总会包含用于注册 JMX 统计 |
| metric.num.samples        | int     | 2        | low         | 用于维护 metrics 的样本数                                    |
| metric.sample.window.ms   | long    | 30000    | low         | metrics 系统维护可配置的样本数量，在一个可修正的window size。这项配置配置了窗口大小，例如。我们可能在 30s 的期间维护两个样本。当一个窗口推出后，我们会擦除并重写最老的窗口 |
| recoonect.backoff.ms      | long    | 10       | low         | 连接失败时，当我们重新连接时的等待时间。这避免了客户端反复重连 |
| retry.backoff.ms          | long    | 100      | low         | 在试图重试失败的 produce 请求之前的等待时间。避免陷入发送 - 失败 的死循环中 |



- 其他配置项

| <span>property（属性）</span>      |  <span style="display:inline-block;width: 200px">  default（默认值） </span> | description（描述）                                          |
| --------------------- | ----------------- | ------------------------------------------------------------ |
| metadata.broker.list  |                   | 服务于 bootstrapping。producer 仅用来获取 metadata(topics，partitions，replicas)。发送实际数据的 socket 连接将基于返回的 metadata 数据信息而建立。格 式是: host1:port1，host2:port2 这个列表可以是 brokers 的子列表或者是一个指向 brokers 的 VIP |
| request.required.acks | 0                 | 此配置是表明当一次 produce 请求被认为完成时的确认值。特别是，多少个其他 brokers 必须已经提交了数据到他们的 log 并且向他们的 leader 确认了这些信息。典型的值包括: <br/>0: 表示 producer 从来不等待来自 broker 的确认信息(和 0.7 一样的行为)。这个选择提供了最小的时延但同时风险最大(因为当 server 宕机时，数据将会丢失)。<br/>1: 表示获得 leader replica 已经接收了数据的确认信息。这个选择时延较小同时确保了 server 确认接收成功。<br/>-1: producer 会获得所有同步 replicas 都收到数据的确认。同时时延最大，然而，这种方式并没有完全消除丢失消息的风险，因为同步 replicas 的数量可能是 1.如果你想确保某些 replicas 接收到数据，那么你应该在 topic-level 设置中选项`min.insync.replicas` 设置一下。 |
| request.timeout.ms | 10000 | broker 尽力实现 `request.required.acks` 请求时的等待时间，否则会发送错误到客户端 |
| producer.type | sync | 此选项指定了消息是否在后台线程中异步发送。可供选择的值：<br/>（1）async：异步发送<br/>（2）sync：同步发送<br/>通过将 producer 设置为异步，我们可以批量处理请求(有利于提高吞吐率)但是这也就造成了客户端机器丢掉未发送数据的可能性 |
| serializaer.class | kafka.serializer.DefaultEncoder | 消息的序列化类别。默认编码器输入一个字节 byte[]，然后返回相同的字节 byte[] |
| key.serializaer.class |                   | 关键字Key的序列化类。如果没给与这项，默认情况是和消息一致 |
| partitioner.class | kafka.producer.DefaultPartitioner | 基于哪种方式进行分区。需要实现partitioner 类，用于自定义在 subtopics 之间划分消息。默认 partitioner 基于 key 的 hash 表（散列分区） |
| compression.codec | none | 此项参数可以设置压缩数据的 codec，可选 codec 为:“none”， “gzip”， “snappy” |
| compression.topics | null | 此项参数可以设置某些特定的 topics 是否进行压缩。如果压缩 codec 是NoCompressCodec 之外的 codec，则对指 定的 topics 数据应用这些 codec。如果压缩 topics 列表是空，则将特定的压缩 codec 应用于所有 topics。如果压缩的 codec 是 NoCompressionCodec，压缩对所有 topics 均不可用。 |
| message.send.max.retries | 3 | 此项参数将使 producer 自动重试失败的发送请求。此项参数将指定重试的次数。注意: 设定非 0 值将导致重复某些网络错误：引起 一条发送并引起确认丢失 |
| retry.backoff.ms | 100 | 在每次重试之前，producer 会更新相关 topic 的 metadata，以此进行查看新的 leader 是否分配好了。因为 leader 的选择 需要一点时间，此选项指定更新 metadata 之前 producer 需要等待的时间。 |
| topic.metadata.refresh.interval.ms | 600 * 1000 | producer 一般会在某些失败的情况下 （partition missing，leader 不可用等）更新 topic 的 metadata。他将会规律的循环。<br/>（1）如果你设置为负值，metadata 只有在失败的情况下才更新。<br/>（2）如果设置为 0，metadata 会在每次消息发送后就会更新(不建议这种选择，系统消耗太大)。<br/>重要提示: 更新是有在消息发送后才会发生，因此，如果 producer 从来不发送消息，则 metadata 从来也不会更新。 |
| queue.buffering.max.ms | 5000 | 当应用 async 模式时，用户缓存数据的最大时间间隔。例如，设置为 100ms 时，将会批量处理 100ms 之内消息。这将改善吞吐率， 但是会增加由于缓存产生的延迟。 |
| queue.buffering.max.messages | 10000 | 当使用 async 模式时，在 producer 必须被阻塞或者数据必须丢失之前，可以缓存到队列中的未发送的最大消息条数 |
| batch.num.messages | 20 | 当使用 async 模式时，可以批量处理消息的最大条数。<br/>注意：消息数目已到达这个上限或者是 `queue.buffer.max.ms` 到达，producer 才会处理 |
| send.buffer.bytes | 100 * 1024 | socket 写缓存尺寸 |
| client.id | "" | 这个client id是用户特定的字符串，在每次请求中包含用来追踪调用，他应该逻辑上可以确认是那个应用发出了这个请求。 |

