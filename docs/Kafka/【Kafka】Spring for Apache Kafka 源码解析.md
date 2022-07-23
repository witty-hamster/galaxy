> Spring kafka version 2.7.1

# 自定义 Kafka Consumer 监听容器工厂

1. 需要自定义一个 Configuration 配置类，内部使用 @Bean 控制反转方式创建一个 `KafkaListenerContainerFactory<>` Kafka监听容器工厂对象
2. 创建过程中，可以指定消费者的配置信息、监听者的配置信息



# `@KafkaListener` 注解创建Kafka消费监听者过程

1. 进入 `KafkaListenerAnnotationBeanPostProcessor#postProcessAfterInitialization()` 方法，扫描类上的注解，获取到我们所添加 `@Configuration` 或 `@Component` 注解的类

   - 获取目标类，校验目标类的方法上是否存在 `@KafkaListener` 注解

     ```java
     Map<Method, Set<KafkaListener>> annotatedMethods = MethodIntrospector.selectMethods(targetClass,
     					(MethodIntrospector.MetadataLookup<Set<KafkaListener>>) method -> {
     						Set<KafkaListener> listenerMethods = findListenerAnnotations(method);
     						return (!listenerMethods.isEmpty() ? listenerMethods : null);
     					});
     ```

     

     - 如果存在该注解，则将该注解对应的方法签名添加到 annotatedMethods Map类型的变量中
       - 其中，Map结构中的 key为每一个 `@KafkaListener`注解对应的方法签名，value为当前注解内参数信息集合
     - 如果不存在，则无需加入

2. 当 `annotatedMethods` 变量存在内容时，将对其进行遍历

   ```java
   if (annotatedMethods.isEmpty()) {
   				this.nonAnnotatedClasses.add(bean.getClass());
   				this.logger.trace(() -> "No @KafkaListener annotations found on bean type: " + bean.getClass());
   }
   else {
     // Non-empty set of methods
     for (Map.Entry<Method, Set<KafkaListener>> entry : annotatedMethods.entrySet()) {
       Method method = entry.getKey();
       for (KafkaListener listener : entry.getValue()) {
         processKafkaListener(listener, method, bean, beanName);
       }
     }
     this.logger.debug(() -> annotatedMethods.size() + " @KafkaListener methods processed on bean '"
                       + beanName + "': " + annotatedMethods);
   }
   ```

   

   - 这里将获取到每一个 `@KafkaListener` 注解修饰的方法签名（Key），以及每个方法签名上方 `@KafkaListener` 注解的集合信息
   - 对 `@KafkaListener` 注解集合信息进行遍历，处理每一个注解内容
   - 开始调用 `KafkaListenerAnnotationBeanPostProcessor#processKafkaListener()` 内部方法，处理KafkaListener

3. 进入 `KafkaListenerAnnotationBeanPostProcessor#processKafkaListener()` 方法内部

   - STEP 01. 校验代理，校验当前的类是否是Java代理类

     - 如果是代理类，需要对类型的方法进行进一步处理
     - 如果不是代理类，则直接将方法返回

   - STEP 02. 构建一个 方法监听的Endpoint（端点），将当前方法设置到端点监听中

   - STEP 03. 进入 `KafkaListenerAnnotationBeanPostProcessor#processMainAndRetryListeners()`，检验消费主流程是否需要添加重试策略

     - 检验是否需要创建重试主题，如果不需要创建重试主题，则在控制台会打印如下信息

       ```sh
       No retry topic configuration found for topics + <主题列表>
       ```

   - STEP 04. 如果没有重试主题，则开始进行监听处理

4. 进入 `KafkaListenerAnnotationBeanPostProcessor#processListener()` 内部方法

   - STEP 01. 对 `@KafkaListener` 注解做处理，进入 `KafkaListenerAnnotationBeanPostProcessor#doProcessKafkaListenerAnnotation()` 内部方法，将所有`@KafkaListener`注解中的配置项，添加到 endpoint 中，用于消费监听使用
   - STEP 02. 处理自定义的 KafkaListenerContainerFactory 监听容器工厂
   - STEP 03. 处理异常工具
   - STEP 04. 移除 listenerScope 中指定key的内容

5. 扫描注解完成后、并获取到我们自定义的工厂后，开始进行 KafkaListener 单例模式的实例化 `KafkaListenerAnnotationBeanPostProcessor#afterSingletonsInstantiated()` 方法

6. 最终会调用到 `KafkaConsumer` 类中的构造方法，创建KafkaConsumer 消费者实例对象



# `@KafkaListener` 注解进行消息监听消费过程

- 简要核心过程
  - STEP 01. 通过调用 `KafkaMessageListenerContainer#ListenerConsumer#run()` 方法， 根据我们在自定义消费者容器工厂时所指定的消费者并发个数，创建对应个数的消费者线程
  - STEP 02. 每个消费者线程，调用 `onMessage()` 方法，进行消息的消费处理

