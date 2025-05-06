<!--
 * @Author: leelongxi leelongxi@foxmail.com
 * @Date: 2025-04-05 11:50:20
 * @LastEditors: leelongxi leelongxi@foxmail.com
 * @LastEditTime: 2025-05-06 11:45:54
 * @FilePath: /sbng_cake/shareholder_contracts/README.md
 * @Description: 这是默认设置,请设置`customMade`, 打开koroFileHeader查看配置 进行设置: https://github.com/OBKoro1/koro1FileHeader/wiki/%E9%85%8D%E7%BD%AE
-->
# 部署合约
1. ERC20部署 - PAT/PAX 
2. PAT发售初始量确认

# 重点
1. 直售流程 -> 申购 -> 确认购买引导至 polygon 入金池 -> 入金成功监听(ccip协议) -> 完成链上调用链下
2. chainlinkFC 调用成功后 -> 数据库状态变更 -> 根据 txHash 生成链上认证NFT(erc1155) -> 链上认证NFT 发放给用户(基于pinata和openSea)
3. 完成购买 PAT 进入锁仓阶段 -> 按照时间维度发放 PAX -> 悬崖期一年 一年后线性释放
4. 赎回从项目收益池打出收益(polygon reedem) -> 赎回成功后 -> ccip赎回消息 -> 完成链上调用链下 -> 数据库状态变更 -> PAT 和 PAX burn