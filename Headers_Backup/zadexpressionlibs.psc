scriptname zadexpressionlibs extends quest
faction         property blockexpressionfaction                             auto
zadlibs         property libs                                               auto
bool            property ready                              = false         auto hidden
faction[]       property phonememodifierfactions                            auto
faction[]       property phonememodifierfactions_large                      auto
faction[]       property phonememodifierfactions_ring                       auto
faction[]       property phonememodifierfactions_bit                        auto
faction[]       property phonememodifierfactions_panel                      auto
int[]           property defaultgagexpression_simple                        auto
int[]           property defaultgagexpression_large                         auto
int[]           property defaultgagexpression_ring                          auto
int[]           property defaultgagexpression_bit                           auto
int[]           property defaultgagexpression_panel                         auto
keyword         property gagkeyword_ring                                    auto
keyword         property gagkeyword_bit                                     auto
string property defaultgagexpfile hidden AutoReadonly
string function get() Native
int function round(float afvalue) global Native
float[] function createemptyexpression() global Native
float[] function getcurrentexpression(actor akactor) global Native
bool function applyexpression(actor akactor, sslbaseexpression akexpression, int aistrength, bool abopenmouth=false,int aipriority = 0) Native
bool function applyexpressionraw(actor akactor, float[] apexpression, int aistrength, bool abopenmouth=false,int aipriority = 0) Native
bool function resetexpression(actor akactor, sslbaseexpression akexpression,int aipriority = 0) Native
bool function resetexpressionraw(actor akactor, int aipriority = 0) Native
function setexpressionphonems(float[] apexpression,float[] apphonems) global Native
function resetexpressionphonems(float[] apexpression) global Native
function setexpressionmodifiers(float[] apexpression,float[] apmodifiers) global Native
function setexpressionexpression(float[] apexpression,int aiexpression_type,int aiexpression_strength) global Native
float[] function createrandomexpression() global Native
function applygageffect(actor akactor) Native
function removegageffect(actor akactor) Native
function maintenance() Native
int[] function loadgagexpfromjson(string asfilepath,string asflag = "defaultgagexpression") Native
