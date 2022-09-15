# Java - Time Utils

> Java 时间工具

## 如何获取当前日期是第几周

- 代码参考

  ```java
  public static void main(String[] args) {
    	// 日历抽象类
      Calendar calendar = Calendar.getInstance();
      // 设置星期一为一周开始的第一天
      calendar.setFirstDayOfWeek(Calendar.MONDAY);
      // 设置当前的时间戳
      calendar.setTimeInMillis(System.currentTimeMillis());
      // 获取当前日期属于今年的第几周
      int weekOfYear = calendar.get(Calendar.WEEK_OF_YEAR);
      // 获取当前日期属于哪一年
      int year = calendar.get(Calendar.YEAR);
    	// 打印输出
      System.out.println("weekOfYear : " + weekOfYear);
      System.out.println("year : " + year);
  }
  ```

