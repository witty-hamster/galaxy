# Redis 问题池

## Spring Cloud 微服务中使用Redis遇到问题<span style="color:#ff0000">[Cloud not resolve type id ** into a subtype]</span>

### 使用背景

​		在Spring Cloud微服务中，我们有一个<b style="color:#009900">Login微服务模块</b>，用于进行用户登录校验、生成token做为Redis的key，然后以<b style="color:#009900">UserVo对象</b>的形式直接缓存到Redis中（<b style="color:#009900">没有使用JSON格式序列化对象，直接将对象存入了Redis中</b>）。当在其他的业务微服务中使用用户授权token去Redis获取用户信息时，直接强转变量类型为UserVo时，报如下错误：

```java
org.springframework.data.redis.serializer.SerializationException: Could not read JSON: Could not resolve type id 'com.login.modules.vo.UserVo' into a subtype of [simple type, class java.lang.Object]: no such class found
 at [Source: [B@79ed6999; line: 1, column: 32]; nested exception is com.fasterxml.jackson.databind.exc.InvalidTypeIdException: Could not resolve type id 'com.login.modules.vo.UserVo' into a subtype of [simple type, class java.lang.Object]: no such class found at [Source: [B@79ed6999; line: 1, column: 32] at org.springframework.data.redis.serializer.Jackson2JsonRedisSerializer.deserialize(Jackson2JsonRedisSerializer.java:73)
```

### 报错原因

​		<b style="color:#009900">业务微服务中的UserVo路径和Login微服务中的UserVo路径（全限定名）不同</b>，在Redis取得数据进行类型转换时，因为接收实体类的路径不同，从而导致类型转换失败，报出如上异常。

### 解决方案

​		<b style="color:#000099">将业务微服务中的UserVo路径调整成和Login微服务中的路径一致即可</b>

