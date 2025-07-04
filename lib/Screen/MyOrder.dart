import 'dart:async';
import 'package:customer/Model/Order_Model.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../Helper/Color.dart';
import '../Helper/Constant.dart';
import '../Helper/Session.dart';
import '../Helper/String.dart';
import '../Provider/UserProvider.dart';
import '../ui/styles/DesignConfig.dart';
import '../ui/widgets/AppBtn.dart';
import '../utils/blured_router.dart';
import 'HomePage.dart';
import 'OrderDetail.dart';

class MyOrder extends StatefulWidget {
  const MyOrder({super.key});
  static route(RouteSettings settings) {
    return BlurredRouter(
      builder: (context) {
        return const MyOrder();
      },
    );
  }

  @override
  State<StatefulWidget> createState() {
    return StateMyOrder();
  }
}

List<OrderModel> searchList = [];
int offset = 0;
int total = 0;
int pos = 0;

class StateMyOrder extends State<MyOrder> with TickerProviderStateMixin {
  String? searchText;
  Animation? buttonSqueezeanimation;
  AnimationController? buttonController;
  bool _isNetworkAvail = true;
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = true;
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
      GlobalKey<RefreshIndicatorState>();
  ScrollController scrollController = ScrollController();
  String _searchText = "";
  String _lastsearch = "";
  bool isLoadingmore = true;
  bool isGettingdata = false;
  bool isNodata = false;
  String? activeStatus;
  List<String> statusList = [
    ALL,
    PLACED,
    PROCESSED,
    SHIPED,
    DELIVERD,
    CANCLED,
    RETURNED,
    awaitingPayment,
  ];
  @override
  void initState() {
    scrollController.addListener(_scrollListener);
    searchList.clear();
    offset = 0;
    total = 0;
    getOrder();
    buttonController = AnimationController(
        duration: const Duration(milliseconds: 2000), vsync: this,);
    buttonSqueezeanimation = Tween(
      begin: deviceWidth! * 0.7,
      end: 50.0,
    ).animate(CurvedAnimation(
      parent: buttonController!,
      curve: const Interval(
        0.0,
        0.150,
      ),
    ),);
    _controller.addListener(() {
      if (_controller.text.isEmpty) {
        if (mounted) {
          setState(() {
            _searchText = "";
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _searchText = _controller.text;
          });
        }
      }
      if (_lastsearch != _searchText &&
          ((_searchText.length > 2) || (_searchText == ""))) {
        _lastsearch = _searchText;
        isLoadingmore = true;
        offset = 0;
        getOrder();
      }
    });
    super.initState();
  }

  _scrollListener() {
    if (scrollController.offset >= scrollController.position.maxScrollExtent &&
        !scrollController.position.outOfRange) {
      if (mounted) {
        setState(() {
          getOrder();
        });
      }
    }
  }

  @override
  void dispose() {
    buttonController!.dispose();
    TextEditingController();
    super.dispose();
  }

  Future<void> _playAnimation() async {
    try {
      await buttonController!.forward();
    } on TickerCanceled {
      return;
    }
  }

  Widget noInternet(BuildContext context) {
    return SingleChildScrollView(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        noIntImage(),
        noIntText(context),
        noIntDec(context),
        AppBtn(
          title: getTranslated(context, 'TRY_AGAIN_INT_LBL'),
          btnAnim: buttonSqueezeanimation,
          btnCntrl: buttonController,
          onBtnSelected: () async {
            _playAnimation();
            Future.delayed(const Duration(seconds: 2)).then((_) async {
              _isNetworkAvail = await isNetworkAvailable();
              if (_isNetworkAvail) {
                getOrder();
              } else {
                await buttonController!.reverse();
                if (mounted) setState(() {});
              }
            });
          },
        ),
      ],),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.lightWhite,
      body: _isNetworkAvail
          ? _isLoading
              ? shimmer(context)
              : Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Column(
                    children: [
                      Container(
                          padding: const EdgeInsetsDirectional.only(
                              start: 5.0, end: 5.0,),
                          child: TextField(
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.fontColor,),
                            controller: _controller,
                            decoration: InputDecoration(
                              filled: true,
                              isDense: true,
                              fillColor: Theme.of(context).colorScheme.white,
                              prefixIconConstraints: const BoxConstraints(
                                  minWidth: 40, maxHeight: 20,),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 10,),
                              prefixIcon: SvgPicture.asset(
                                'assets/images/search.svg',
                                colorFilter: ColorFilter.mode(
                                    Theme.of(context).colorScheme.primarytheme,
                                    BlendMode.srcIn,),
                              ),
                              hintText: getTranslated(
                                  context, 'FIND_ORDER_ITEMS_LBL',),
                              hintStyle: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .fontColor
                                      .withOpacity(0.3),
                                  fontWeight: FontWeight.normal,),
                              border: const OutlineInputBorder(
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),),
                      Expanded(
                        child: searchList.isEmpty
                            ? Center(
                                child: Text(getTranslated(context, 'noItem')!),)
                            : RefreshIndicator(
                                color:
                                    Theme.of(context).colorScheme.primarytheme,
                                key: _refreshIndicatorKey,
                                onRefresh: _refresh,
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  controller: scrollController,
                                  padding: const EdgeInsetsDirectional.only(
                                      top: 5.0,),
                                  itemCount: searchList.length,
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  itemBuilder: (context, index) {
                                    OrderItem? orderItem;
                                    try {
                                      if (searchList[index]
                                          .itemList!
                                          .isNotEmpty) {
                                        orderItem =
                                            searchList[index].itemList![0];
                                      }
                                      if (isLoadingmore &&
                                          index == (searchList.length - 1) &&
                                          scrollController.position.pixels <=
                                              0) {
                                        getOrder();
                                      }
                                    } on Exception catch (_) {}
                                    return orderItem == null
                                        ? const SizedBox.shrink()
                                        : productItem(
                                            index,
                                            orderItem,
                                            searchList[index].activeStatus,
                                            searchList[index]
                                                .dateTime
                                                .toString(),);
                                  },
                                ),),
                      ),
                      if (isGettingdata) Padding(
                              padding: const EdgeInsetsDirectional.only(
                                  top: 5, bottom: 5,),
                              child: CircularProgressIndicator(
                                color:
                                    Theme.of(context).colorScheme.primarytheme,
                              ),
                            ) else const SizedBox.shrink(),
                    ],
                  ),
                )
          : noInternet(context),
    );
  }
AppBar myOrdersAppBar(BuildContext context, String title) {
  return AppBar(
    elevation: 0,
    titleSpacing: 0,
    backgroundColor: Theme.of(context).colorScheme.white,
    automaticallyImplyLeading: false, // No back button!
    title: Text(
      title,
      style: TextStyle(
        color: Theme.of(context).colorScheme.primarytheme,
        fontWeight: FontWeight.normal,
      ),
    ),
  );
}

  Future<void> _refresh() {
    if (mounted) {
      setState(() {
        offset = 0;
        total = 0;
        isLoadingmore = true;
        _isLoading = true;
      });
    }
    return getOrder();
  }

  Future<void> getOrder() async {
    _isNetworkAvail = await isNetworkAvailable();
    if (_isNetworkAvail) {
      try {
        if (isLoadingmore) {
          if (mounted) {
            setState(() {
              isLoadingmore = false;
              isGettingdata = true;
              if (offset == 0) {
                searchList = [];
              }
            });
          }
          final parameter = {
            USER_ID: context.read<UserProvider>().userId,
            OFFSET: offset.toString(),
            LIMIT: perPage.toString(),
            SEARCH: _searchText.trim(),
          };
          if (activeStatus != null) {
            if (activeStatus == awaitingPayment) activeStatus = "awaiting";
            parameter[ACTIVE_STATUS] = activeStatus!;
            parameter[ACTIVE_STATUS] = activeStatus!;
          }
          apiBaseHelper.postAPICall(getOrderApi, parameter).then((getdata) {
            final bool error = getdata["error"];
            isGettingdata = false;
            if (offset == 0) isNodata = error;
            if (!error) {
              final data = getdata["data"];
              if (data.length != 0) {
                final List<OrderModel> items = [];
                final List<OrderModel> allitems = [];
                items.addAll((data as List)
                    .map((data) => OrderModel.fromJson(data))
                    .toList(),);
                allitems.addAll(items);
                for (final OrderModel item in items) {
                  searchList.where((i) => i.id == item.id).map((obj) {
                    allitems.remove(item);
                    return obj;
                  }).toList();
                }
                searchList.addAll(allitems);
                isLoadingmore = true;
                offset = offset + perPage;
              } else {
                isLoadingmore = false;
              }
            } else {
              isLoadingmore = false;
            }
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          }, onError: (error) {
            setSnackbar(error.toString(), context);
          },);
        }
      } on TimeoutException catch (_) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            isLoadingmore = false;
          });
        }
        setSnackbar(getTranslated(context, 'somethingMSg')!, context);
      }
    } else {
      if (mounted) {
        setState(() {
          _isNetworkAvail = false;
          _isLoading = false;
        });
      }
    }
    return;
  }

  productItem(
      int index, OrderItem orderItem, String? activeStatus, String? date,) {
    String name = orderItem.name ?? "";
    name =
        "$name ${searchList[index].itemList!.length > 1 ? " and more items" : ""} ";
    return Card(
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(7),
        child: Column(children: <Widget>[
          Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
            ClipRRect(
                borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(7.0),
                    topLeft: Radius.circular(7.0),),
                child: networkImageCommon(orderItem.image!, 100, false,
                    height: 100, width: 100,),),
            Expanded(
                flex: 9,
                child: Padding(
                    padding: const EdgeInsetsDirectional.only(
                        start: 10.0, end: 5.0, bottom: 8.0, top: 8.0,),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            "$activeStatus on $date"
                                .replaceAll("_", ' ')
                                .toTitleCase(),
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall!
                                .copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .fontColor,),
                          ),
                          Padding(
                              padding:
                                  const EdgeInsetsDirectional.only(top: 10.0),
                              child: Text(
                                name,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall!
                                    .copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .lightBlack2,
                                        fontWeight: FontWeight.normal,
                                        fontSize: 12,),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),),
                        ],),),),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(right: 3.0),
              child: Icon(
                Icons.arrow_forward_ios_rounded,
                color: Theme.of(context).colorScheme.primarytheme,
                size: 15,
              ),
            ),
          ],),
        ],),
        onTap: () async {
          FocusScope.of(context).unfocus();
          final result = await Navigator.push(
            context,
            CupertinoPageRoute(
                builder: (context) => OrderDetail(
                      model: searchList[index],
                      index: index,
                    ),),
          );
          if (mounted && result == "update") {
            setState(() {
              _isLoading = true;
              isLoadingmore = true;
              offset = 0;
              total = 0;
              searchList.clear();
              getOrder();
            });
          }
        },
      ),
    );
  }

  List<Widget> getStatusList() {
    return statusList
        .asMap()
        .map(
          (index, element) => MapEntry(
            index,
            Column(
              children: [
                SizedBox(
                  width: double.maxFinite,
                  child: TextButton(
                      child: Text(capitalize(statusList[index]),
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall!
                              .copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .lightBlack,),),
                      onPressed: () {
                        setState(() {
                          activeStatus = index == 0 ? null : statusList[index];
                          isLoadingmore = true;
                          offset = 0;
                        });
                        getOrder();
                        Navigator.pop(context, 'option $index');
                      },),
                ),
                Divider(
                  color: Theme.of(context).colorScheme.lightBlack,
                  height: 1,
                ),
              ],
            ),
          ),
        )
        .values
        .toList();
  }
}

extension StringExtension on String {
  String toCapitalized() =>
      length > 0 ? '${this[0].toUpperCase()}${substring(1).toLowerCase()}' : '';
  String toTitleCase() => replaceAll(RegExp(' +'), ' ')
      .split(' ')
      .map((str) => str.toCapitalized())
      .join(' ');
}
