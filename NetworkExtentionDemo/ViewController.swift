//
//  ViewController.swift
//  NetworkExtentionDemo
//
//  Created by 黄龙 on 2023/5/9.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        let button = UIButton(frame: CGRect(x: 100, y: 100, width: 100, height: 50))
        view.addSubview(button)
        button.setTitle("开启VPN", for: .normal)
        button.setTitleColor(.green, for: .normal)
        button.layer.borderWidth = 0.5
        button.layer.borderColor = UIColor.green.cgColor
        button.layer.cornerRadius = 6
        button.addActionWithBlock { sender in
            
        }
    }


}



/*
 button点击事件封装
 */
extension UIButton {
      // 定义关联的Key
      private struct UIButtonKeys {
         static var clickKey = "UIButton+Extension+ActionKey"
      }
      
      func addActionWithBlock(_ closure: @escaping (_ sender:UIButton)->()) {
//把闭包作为一个值 先保存起来;
//@escaping定义逃逸类型的闭包，
//如果一个闭包被作为一个参数传递给一个函数，并且在函数return之后才被唤起执行，那么这个闭包是逃逸闭包。
/*
 关联是指把两个对象相互关联起来，使得其中的一个对象作为另外一个对象的一部分。
 其本质是在类的定义之外为类增加额外的存储空间。
 
 使用关联，我们可以不用修改类的定义而为其对象增加存储空间。
 这在我们无法访问到类的源码的时候，或者是考虑到二进制兼容性的时候，非常有用。
 关联是基于关键字的，因此，我们可以为任何对象增加任意多的关联，每个都使用不同的关键字即可。
 关联是可以保证被关联的对象在关联对象的整个生命周期都是可用的（在垃圾自动回收环境下也不会导致资源不可回收）。
 
 objc_setAssociatedObject为OC的运行时函数
 void objc_setAssociatedObject(id object, const void *key, id value, objc_AssociationPolicy policy)
 id object                     :表示关联者，是一个对象，变量名理所当然也是object
 const void *key               :获取被关联者的索引key
 id value                      :被关联者，这里是一个block
 objc_AssociationPolicy policy :关联时采用的协议，有assign，retain，copy等协议，一般使用OBJC_ASSOCIATION_RETAIN_NONATOMIC
 关键字 : 是一个void类型的指针。每一个关联的关键字必须是唯一的。通常都是会采用静态变量来作为关键字。
 关联策略表明了相关的对象是通过赋值(assign)，保留引用(retain)还是复制(copy)的方式进行关联的；
 还有这种关联是原子的还是非原子的。这里的关联策略和声明属性时的很类似。这种关联策略是通过使用预先定义好的常量来表示的。
*/
         objc_setAssociatedObject(self, &UIButtonKeys.clickKey, closure, objc_AssociationPolicy.OBJC_ASSOCIATION_COPY)
/*
1、  OBJC_ASSOCIATION_ASSIGN              相当于weak
2 、 OBJC_ASSOCIATION_RETAIN_NONATOMIC    相当于strong和nonatomic
3、  OBJC_ASSOCIATION_COPY_NONATOMIC      相当于copy和nonatomic
4、  OBJC_ASSOCIATION_RETAIN              相当于strong和atomic
5、  OBJC_ASSOCIATION_COPY                相当于copy和atomic
 */
        
//给按钮添加传统的点击事件，调用写好的方法
         self.addTarget(self, action: #selector(my_ActionForTapGesture), for: .touchUpInside)
      }
    
      @objc private func my_ActionForTapGesture() {
         //获取闭包值
         let obj = objc_getAssociatedObject(self, &UIButtonKeys.clickKey)
         if let action = obj as? (_ sender:UIButton)->() {
             //调用闭包
             action(self)
         }
      }
}
