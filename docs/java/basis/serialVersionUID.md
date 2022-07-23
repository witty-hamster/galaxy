# serialVersionUID 问题

> 类文件的版本标识，如果两个类对象是完全一致的，并且所设置的版本标识serialVersionUID也是一致的话，则可以在IO流中完成类文件的序列化与反序列化操作。否则将会报错

## 什么是序列化？

​		在创建数据对象的时候，我们经常会让对象实现 `java.io.Serializable` 接口，Serializable接口是启用其序列化功能的接口。实现 `java.io.Serializable`  接口的类是可序列化的。没有实现此接口的类将不能使它们的任意状态被序列化或反序列化。

- `java.io.Serializable` 接口没有任何实现，这类接口一般叫做标识接口

  ```java
  package java.io;
  
  public interface Serializable {
  }
  ```

## 为什么要序列化呢？

​		序列化是指把Java对象转换为字节序列的过程，反序列化是指把字节序列恢复为Java对象的过程。任何类型只要实现了 Serializable接口，就可以被保存到文件中，或者作为数据流通过网络发送到别的地方。也可以用管道来传输到系统的其他程序中。由此可见序列化操作的重要性。

## serialVersionUID 作用

​		当Java对象做序列化和反序列化操作的时候，需要验证版本一致性。serialVersionUID 的作用是标识版本，主要用于程序的版本控制。如果 serialVersionUID 一致，说明他们的版本是一样的；反之就说明版本不同。比如，当我们进行序列化操作一个对象，会把当前的版本 serialVersionUID 写入到文件之中，在运行的时候，它就会监测当前版本的 serialVersionUID 与编写版本是否一致。

​		Java对象实现 `java.io.Serializable` 接口后，可以定义 serialVersionUID，也可以不定义 serialVersionUID

- 当不定义时，一般开发工具会有提示警告，可直接通过开发工具生成对应的版本标识
- 如果没有定义一个名为 serialVersionUID、类型为long的变量，Java序列化机制会根据编译的class文件自动生成一个serialVersionUID变量，即隐式声明。默认的serialVersionUID计算时，对类详细信息高度敏感（类名、接口名、成员方法及属性等），并且这些详细信息可能因编译器而异。因此只有同一次编译生成的class才会生成相同的serialVersionUID。此时如果对某个类进行修改的话，那么版本上面是不兼容的，就会出现反序列化报错问题



