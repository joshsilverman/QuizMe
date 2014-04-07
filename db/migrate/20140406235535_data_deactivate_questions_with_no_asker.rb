class DataDeactivateQuestionsWithNoAsker < ActiveRecord::Migration
  def up
    deprecate_question_ids = [5165, 5154, 5155, 5156, 5157, 5158, 5160, 5161, 
        5152, 5153, 5167, 5168, 5170, 5171, 5173, 5174, 5176, 5177, 5178, 5180, 
        5181, 5183, 5184, 5185, 5164, 5166, 5193, 5194, 5196, 5197, 5199, 5200, 
        5201, 5203, 5205, 5207, 5204, 5188, 5190, 5206, 5209, 5211, 5208, 5218, 
        5222, 5214, 5215, 5219, 5220, 5221, 5225, 5224, 5210, 5163, 5192, 3283, 
        4462, 3241, 3242, 3244, 3245, 3247, 3249, 3050, 3052, 3053, 3055, 3057, 
        3058, 3059, 3060, 3061, 3062, 3064, 3065, 3066, 3068, 3069, 3070, 3156, 
        3073, 3074, 3076, 3077, 3079, 3081, 3082, 3084, 3085, 3087, 3088, 3091, 
        3092, 3094, 3095, 3097, 3158, 3098, 3101, 3102, 3142, 3105, 3106, 3107, 
        3108, 3110, 3111, 3112, 3114, 3207, 3117, 3118, 3119, 3121, 3122, 3157, 
        3127, 3129, 3130, 3131, 3133, 3134, 3135, 3136, 3138, 3139, 3140, 3143, 
        3145, 3146, 3149, 3150, 3151, 3153, 3154, 3162, 3163, 3165, 3166, 3168, 
        3169, 3171, 3173, 3174, 3175, 3177, 3179, 3180, 3181, 3183, 3185, 3186, 
        3187, 3189, 3192, 3193, 3194, 3196, 3198, 3199, 3201, 3202, 3203, 3204, 
        3206, 3208, 3210, 3211, 3213, 3214, 3215, 3217, 3276, 3220, 3221, 3223, 
        3224, 3226, 3227, 3228, 3230, 3231, 3233, 3234, 3236, 3238, 3251, 3252, 
        3254, 3255, 3256, 3258, 3260, 3261, 3262, 3263, 3265, 3267, 3269, 3271, 
        3272, 3273, 3274, 3278, 3280, 3282, 3284, 3286, 3287, 3289, 3290, 3291, 
        3293, 3295, 5151, 5159, 5162, 5169, 5172, 5175, 5179, 5182, 5186, 5191, 
        5195, 5198, 5202, 5187, 5189, 5226, 5212, 5213, 5216, 5223, 5217, 5150, 
        4465, 3239, 3240, 3243, 3246, 3248, 3049, 3051, 3054, 3056, 3147, 3063, 
        3141, 3067, 3071, 3072, 3075, 3078, 3080, 3083, 3086, 3089, 3090, 3093, 
        3096, 3099, 3100, 3103, 3104, 3109, 3113, 3115, 3222, 3116, 3120, 3123, 
        3124, 3125, 3126, 3128, 3132, 3137, 3144, 3148, 3152, 3155, 3159, 3160, 
        3161, 3164, 3167, 3170, 3172, 3176, 3178, 3182, 3184, 3188, 3190, 3191, 
        3195, 3197, 3200, 3205, 3209, 3212, 3216, 3218, 3219, 3225, 3229, 3232, 
        3235, 3237, 3250, 3253, 3257, 3259, 3264, 3266, 3268, 3270, 3275, 3277, 
        3279, 3281, 3285, 3288, 3292, 3294, 3296]

    deprecate_question_ids.each do |id|
      question = Question.find_by id: id
      return if !question
      return if question.asker

      question.update status: nil
    end
  end
end
