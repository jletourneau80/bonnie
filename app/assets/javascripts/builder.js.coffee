bonnie = @bonnie || {}

class @bonnie.Builder
  constructor: (data_criteria, measure_period, preconditions, fields, value_sets, statuses_by_definition) ->
    @measure_period = new bonnie.MeasurePeriod(measure_period)
    @field_map = fields
    @data_criteria = {}
    @value_sets = {}
    @populationQuery = new queryStructure.Query()
    @denominatorQuery = new queryStructure.Query()
    @numeratorQuery = new queryStructure.Query()
    @exclusionsQuery = new queryStructure.Query()
    @exceptionsQuery = new queryStructure.Query()
    @preconditions = preconditions || {}
    @value_sets[s.oid] = s for s in value_sets
    @statuses_by_definition = statuses_by_definition
    for key in _.keys(data_criteria)
      @data_criteria[key] = new bonnie.DataCriteria(key, data_criteria[key], @measure_period)

  dataKeys: =>
    _.keys(@data_criteria)

  dataCriteria: (key) =>
    @data_criteria[key]

  updateDisplay: () =>
    alert "updating display: " + @data_criteria

  renderMeasureJSON: (data) =>
    if (!$.isEmptyObject(data.population))
      @populationQuery.rebuildFromJson(data.population)
      @addParamItems(@populationQuery.toJson(),$("#initialPopulationItems"))
      $("#initialPopulationItems .paramGroup").addClass("population")

    if (!$.isEmptyObject(data.denominator))
      @denominatorQuery.rebuildFromJson(data.denominator)
      @addParamItems((if data.denominator.items.length then @denominatorQuery.toJson() else 'DENOMINATOR_PLACEHOLDER'),$("#eligibilityMeasureItems"))

    if (!$.isEmptyObject(data.numerator))
      @numeratorQuery.rebuildFromJson(data.numerator)
      @addParamItems(@numeratorQuery.toJson(),$("#outcomeMeasureItems"))

    if (!$.isEmptyObject(data.exclusions))
      @exclusionsQuery.rebuildFromJson(data.exclusions)
      @addParamItems(@exclusionsQuery.toJson(),$("#exclusionMeasureItems"))

    if (!$.isEmptyObject(data.exceptions))
      @exceptionsQuery.rebuildFromJson(data.exceptions)
      @addParamItems(@exceptionsQuery.toJson(),$("#exceptionMeasureItems"))
    @._bindClickHandler()

  _bindClickHandler: (selector) ->
    $(selector || '#initialPopulationItems, #eligibilityMeasureItems, #outcomeMeasureItems, #exclusionMeasureItems, #exceptionMeasureItems').find('.paramItem[data-precondition-id], .paramItem[data-criteria-id]').click((event) =>
      $('.paramItem').removeClass('editing')
      return if $('#text_view_styles').prop('disabled')-1
      $('.paramItem[data-criteria-id=' + $(event.currentTarget).data('criteria-id') + '], .paramItem[data-precondition-id=' + $(event.currentTarget).data('precondition-id') + ']').addClass('editing')
      @editDataCriteria(event.currentTarget)
      event.stopPropagation()
    )

  renderCriteriaJSON: (data, target) =>
    @addParamItems(data,target)

  editDataCriteria: (element) =>
    leaf = $(element)

    top = $('#workspace > div').css('top')
    $('#workspace').empty();
    element =
      if data_criteria = @dataCriteria($(element).data('criteria-id'))
        bonnie.template('data_criteria_edit', $.extend({}, data_criteria, {precondition_id: $(element).data('precondition-id')})).appendTo('#workspace')
      else if $(element).data('precondition-id')
        bonnie.template('precondition_edit', {id: $(element).data('precondition-id'), precondition_id: $(element).data('precondition-id')}).appendTo('#workspace')


    offset = leaf.offset().top + leaf.height()/2 - $('#workspace').offset().top - element.height()/2
    offset = 0 if offset < 0
    maxoffset = $('#measureEditContainer').height() - element.outerHeight(true) - $('#workspace').position().top - $('#workspace').outerHeight(true) + $('#workspace').height()
    offset = maxoffset if offset > maxoffset
    element.css("top", offset)
    arrowOffset = leaf.offset().top + leaf.height()/2 - element.offset().top - $('.arrow-w').outerHeight()/2
    arrowOffset = 0 if arrowOffset < 0
    $('.arrow-w').css('top', arrowOffset)
    element.css("top", top)
    element.animate({top: offset})

    if data_criteria
      data_criteria.getProperty = (ns) ->
        obj = this
        y = ns.split(".")
        for i in [0..y.length-1]
          if obj[y[i]]
            obj = obj[y[i]]
          else
            return
        obj

      element.find('select[name=status]').val(data_criteria.status)
      element.find('select[name=category]').val(data_criteria.category).on('change', ->
        $(this).parents('form').find('select[name=subcategory]').empty().append(
          bonnie.builder.statuses_by_definition[$(this).val()].map( (e)->
            $(document.createElement('option')).val(e).text(e).get(0)
          )
        )
      ).trigger('change');
      element.find('input[type=radio][name=value_type]').change(
        ( ->
          element.find('.criteria_value_value').children().show().not('.' +
            switch(if @ instanceof String then @toString() else $(@).val())
              when 'PQ' then 'data_criteria_value'
              when 'IVL_PQ' then 'data_criteria_range'
              when 'CD' then 'data_criteria_oid'
          ).hide()
          arguments.callee
        ).call data_criteria.value && data_criteria.value.type || 'PQ'
      ).filter('[value=' + (data_criteria.value && data_criteria.value.type || 'PQ') + ']').prop('checked', 'checked')
      element.find('select.data_criteria_oid').val(data_criteria.value && data_criteria.value.code_list_id)

      element.find('select[name=negation]').val('true' if data_criteria.negation)
      element.find('.negation_reason_oid').slideDown() if data_criteria.negation
      element.find('select[name=negation_code_list_id]').val(data_criteria.negation_code_list_id)

      temporal_element = $(element).find('.temporal_reference')
      $.each(data_criteria.temporal_references, (i, e) ->
        $(temporal_element[i]).find('.temporal_type').val(e.type)
        $(temporal_element[i]).find('.temporal_relation').val(
          (if e.offset && e.offset.value < 0 then 'lt' else 'gt') +
          if e.offset && e.offset.inclusive then 'e' else ''
        )
        $(temporal_element[i]).find('.temporal_range_high_relation').val(if e.range && e.range.high && e.range.high.inclusive then 'lte' else 'lt')
        $(temporal_element[i]).find('.temporal_range_high_unit').val(if e.range && e.range.high then e.range.high.unit)
        $(temporal_element[i]).find('.temporal_range_low_relation').val(if e.range && e.range.low && e.range.low.inclusive then 'gte' else 'gt')
        $(temporal_element[i]).find('.temporal_range_low_unit').val(if e.range && e.range.low then e.range.low.unit)
        $(temporal_element[i]).find('.temporal_drop_zone').each((i, e) ->
          fillDrop(e);
        ).droppable({ tolerance: 'pointer', greedy: true, accept: 'label.ui-draggable', drop: ((e,ui) -> fillDrop(e)) });
      );

      subset_element = $(element).find('.subset_operator')
      $.each(data_criteria.subset_operators, (i, e) ->
        $(subset_element[i]).find('.subset_type').val(e.type)
        if e.range && e.range.low && e.range.high && e.range.low.equals(e.range.high) && e.range.low.inclusive
          $(subset_element[i]).find('.subset_range_type[value=value]').attr('checked', true)
          $(subset_element[i]).find('.data_criteria_value').siblings().hide()
        else
          $(subset_element[i]).find('.subset_range_type[value=range]').attr('checked', true)
          $(subset_element[i]).find('.data_criteria_range').siblings().hide()
          $(subset_element[i]).find('.data_criteria_range_high_relation').val(if e.range && e.range.high && e.range.high.inclusive then 'lte' else 'lt')
          $(subset_element[i]).find('.data_criteria_range_low_relation').val(if e.range && e.range.low && e.range.low.inclusive then 'gte' else 'gt')
      )

      field_element = $(element).find('.field_value')
      i = 0
      $.each(data_criteria.field_values || {}, (k, e) ->
        $(f = field_element[i++]).find('.field_type').val(k)
        $(f).find('.data_criteria_oid').val(e.code_list_id)
      )

  getNextChildCriteriaId: (base, start)=>
    id = start || 1
    id++  while @data_criteria[base + id]
    base+id

  editDataCriteria_submit: (form) =>
    temporal_references = []
    subset_operators = []
    field_values = {}

    $(form).find('.temporal_reference').each((i, e) ->
      temporal_references.push({
        type: $(e).find('.temporal_type').val()
        range: {
          type: 'IVL_PQ'
          high: {
            type: 'PQ'
            value: $(e).find('.temporal_range_high_value').val()
            unit: $(e).find('.temporal_range_high_unit').val()
            'inclusive?': $(e).find('.temporal_range_high_relation').val().indexOf('e') > -1
          } if $(e).find('.temporal_range_high_value').val()
          low: {
            type: 'PQ'
            value: $(e).find('.temporal_range_low_value').val()
            unit: $(e).find('.temporal_range_low_unit').val()
            'inclusive?': $(e).find('.temporal_range_low_relation').val().indexOf('e') > -1
          } if $(e).find('.temporal_range_low_value').val()
        }
        reference: (
          if $(e).find('.temporal_reference_value').length > 1
            $.post('/measures/' + $(form).find('input[type=hidden][name=id]').val() + '/upsert_criteria', {
              criteria_id: (id = bonnie.builder.getNextChildCriteriaId($(form).find('input[type=hidden][name=criteria_id]').val() + '_CHILDREN_', id))
              children_criteria: $.map($(e).find('.temporal_reference_value'), ((e) -> $(e).val()))
              standard_category: 'temporal'
              type: 'derived'
            }) && id
          else $(e).find('.temporal_reference_value').val()
        )
      })
    )
    $(form).find('.subset_operator').each((i, e) ->
      subset_operators.push({
        type: $(e).find('.subset_type').val()
        value: {
          type: 'IVL_PQ'
          high: if $(e).find('.subset_range_type:checked').val() == 'value' then {
            type: 'PQ'
            value: $(e).find('.data_criteria_value_value').val()
            unit: $(e).find('.data_criteria_value_unit').val()
            'inclusive?': true
          } else {
            type: 'PQ'
            value: $(e).find('.data_criteria_range_high_value').val()
            unit: $(e).find('.data_criteria_range_high_unit').val()
            'inclusive?': $(e).find('.data_criteria_range_high_relation').val().indexOf('e') > -1
          } if $(e).find('.data_criteria_range_high_value').val()
          low: if $(e).find('.subset_range_type:checked').val() == 'value' then {
            type: 'PQ'
            value: $(e).find('.data_criteria_value_value').val()
            unit: $(e).find('.data_criteria_value_unit').val()
            'inclusive?': true
          } else {
            type: 'PQ'
            value: $(e).find('.data_criteria_range_low_value').val()
            unit: $(e).find('.data_criteria_range_low_unit').val()
            'inclusive?': $(e).find('.data_criteria_range_low_relation').val().indexOf('e') > -1
          } if $(e).find('.data_criteria_range_low_value').val()
        }
      })
    )
    $(form).find('.field_value').each((i, e) =>
      field_values[$(e).find('.field_type').val()] = {
        code_list_id: oid = $(e).find('.data_criteria_oid').val()
        title: @value_sets[oid].concept
        type: 'CD'
      }
    )
    !$(form).ajaxSubmit({
      data: {
        value: JSON.stringify(
          switch $(form).find('.criteria_value input[type=radio][name=value_type]:checked').val()
            when 'PQ'
              {
                value: $(form).find('.criteria_value .data_criteria_value_value').val()
                unit: $(form).find('.criteria_value .data_criteria_value_unit').val()
              }
            when 'IVL_PQ'
              {
                low: {
                  type: 'PQ'
                  value: $(form).find('.criteria_value .data_criteria_range_low_value').val()
                  unit: $(form).find('.criteria_value .data_criteria_range_low_unit').val()
                } if $(form).find('.criteria_value .data_criteria_range_low_value').val()
                high: {
                  type: 'PQ'
                  value: $(form).find('.criteria_value .data_criteria_range_high_value').val()
                  unit: $(form).find('.criteria_value .data_criteria_range_high_unit').val()
                } if $(form).find('.criteria_value .data_criteria_range_high_value').val()
              }
            when 'CD'
              {
                code_list_id: $(form).find('.criteria_value .data_criteria_oid').val()
                title: $(form).find('.criteria_value .data_criteria_oid > option:selected').text()
              }
        )
        temporal_references: JSON.stringify(temporal_references)
        subset_operators: JSON.stringify(subset_operators)
        field_values: JSON.stringify(field_values)
      }
      success: (r) =>
        @data_criteria[r.id] = new bonnie.DataCriteria(r.id, r, @measure_period)
        @addParamItems(@populationQuery.toJson(),$("#initialPopulationItems").empty())
        @_bindClickHandler("#initialPopulationItems")
        @addParamItems(@denominatorQuery.toJson(),$("#eligibilityMeasureItems").empty())
        @_bindClickHandler("#eligibilityMeasureItems")
        @addParamItems(@numeratorQuery.toJson(),$("#outcomeMeasureItems").empty())
        @_bindClickHandler("#outcomeMeasureItems")
        @addParamItems(@exclusionsQuery.toJson(),$("#exclusionMeasureItems").empty())
        @_bindClickHandler("#exclusionMeasureItems")
        @addParamItems(@exceptionsQuery.toJson(),$("#exceptionMeasureItems").empty())
        @_bindClickHandler("#exceptionMeasureItems")

        @showSaved('#workspace')

        $('.paramItem[data-criteria-id=' + $('#workspace form > input[name=criteria_id]').val() + ']').stop(true).css('background-color', '#AAD9FF').animate({'background-color': '#DDF0FF'}, 1200, ->
            $(@).css('background-color', '').addClass('editing')
        );
    });

  showSaved: (e) =>
    $(e).find('.edit_save_message').empty().append('<span style="color: green">Saved!</span>')
    setTimeout (->
      $(e).find(".edit_save_message > span").fadeOut ->
        $(this).remove()
    ), 3000

  pushTree: (queryObj) =>
    finder = queryObj
    switch (
      (while finder.parent
        finder = finder.parent
      ).pop()
    )
      when @populationQuery.structure
        $("#initialPopulationItems").empty()
        @saveTree(@populationQuery.toJson(), 'IPP', 'Initial Patient Population')
        @_bindClickHandler("#initialPopulationItems")
      when @denominatorQuery.structure
        $("#eligibilityMeasureItems").empty()
        @saveTree(@denominatorQuery.toJson(), 'DENOM', 'Denominator')
        @_bindClickHandler("#eligibilityMeasureItems")
      when @numeratorQuery.structure
        $("#outcomeMeasureItems").empty()
        @saveTree(@numeratorQuery.toJson(), 'NUMER', 'Numerator')
        @_bindClickHandler("#outcomeMeasureItems")
      when @exclusionsQuery.structure
        $("#exclusionMeasureItems").empty()
        @saveTree(@exclusionsQuery.toJson(), 'EXCL', 'Exclusions')
        @_bindClickHandler("#exclusionMeasureItems")
      when @exceptionsQuery.structure
        $("#exceptionMeasureItems").empty()
        @saveTree(@exceptionsQuery.toJson(), 'DENEXCEP', 'Denominator Exceptions')
        @_bindClickHandler("#exceptionMeasureItems")

  saveTree: (query, key, title) ->
    ((o) ->
      delete o.parent
      for k of o
        arguments.callee o[k]  if typeof o[k] is "object"
    ) query = query
    $.post(bonnie.builder.update_url, {'csrf-token': $('meta[name="csrf-token"]').attr('content'), data: {'conjunction?': true, type: key, title: title, preconditions: query}}, (r) =>
      for key in _.keys(r.data_criteria)
        @data_criteria[key] = new bonnie.DataCriteria(key, r.data_criteria[key], @measure_period)
      @renderMeasureJSON(r.population_criteria)
    )

  addParamItems: (obj,elemParent,container) =>
    builder = bonnie.builder
    items = obj["items"]
    data_criteria = builder.dataCriteria(obj.id) if (obj.id)
    parent = obj.parent

    makeDropFn = (self) ->
      queryObj = parent ? obj
      dropFunction = (event,ui) ->
        target = event.currentTarget
        drop_Y = event.pageY
        child_items = $(@).children(".paramGroup")
        for item in child_items
          item_top = $(item).offset().top;
          item_height = $(item).height();
          item_mid = item_top + Math.round(item_height/2)
        # tgt = queryObj.parent ? queryObj
        if queryObj instanceof queryStructure.Container
          tgt = queryObj
        else
          tgt = queryObj.parent
        tgt?.add(
          id: $(ui.draggable).data('criteria-id')
        )
        $(@).removeClass('droppable')
        $('#workspace').empty()

        bonnie.builder.pushTree(queryObj)
      return dropFunction


    if $(elemParent).not(".droppable").hasClass('paramItem')
      $(elemParent).data("query-struct",parent)
      elemParent.droppable(
          over:  @._over
          tolerance:'pointer'
          greedy: true
          accept:'label.ui-draggable'
          out:  @._out
          drop: makeDropFn(@)

      )
    if (data_criteria?)
      if (data_criteria.subset_operators?)
        for subset_operator in data_criteria.subset_operators
          $(elemParent).append("<span class='#{subset_operator.type} subset-operator'>#{subset_operator.title()}</span>")

      if (data_criteria.children_criteria?)
        items = data_criteria.childrenCriteriaItems()
      else
        # we dont have a nested measure clause, add the item to the bottom of the list
        # if (!elemParent.hasClass("paramItem"))
        items = data_criteria.temporalReferenceItems()
        elemParent = bonnie.template('param_group', obj).appendTo(elemParent).find(".paramItem:last").data('logic-id', obj)
        $(elemParent).parent().find('.display_name').click((e)->
          $(this).toggleClass('collapsed')
          $(this).siblings().slideToggle()
          e.stopPropagation()
        );
        data_criteria.asHtml('data_criteria_logic').appendTo(elemParent)

    else if obj == 'DENOMINATOR_PLACEHOLDER'
      bonnie.template('param_group').appendTo(elemParent).find(".paramItem:last").data('logic-id', obj).append(bonnie.template('data_criteria_logic', {title: 'Denominator consists only of IPP', category: 'initial patient population'}));

    if ($.isArray(items))
      conjunction = obj['conjunction']
      builder.renderParamItems(conjunction, items, elemParent, obj)

  _over: ->
    $(@).parents('.paramItem').removeClass('droppable')
    $(@).addClass('droppable')

  _out: ->
    $(@).removeClass('droppable')

  renderParamItems: (conjunction, items, elemParent, obj) =>
    neg = (obj.negation || false) && obj.negation != 'false'
    builder = bonnie.builder

    if items.length > 1
      elemParent = bonnie.template('param_group', $.extend({}, obj, {conjunction: conjunction || items[0] && items[0].conjunction})).appendTo(elemParent).find(".paramItem:last").data('logic-id', obj)
      $(elemParent).parent().find('.display_name').click((e)->
        $(this).toggleClass('collapsed')
        $(this).siblings().slideToggle();
        e.stopPropagation()
      );

    $.each(items, (i,node) ->
      $(elemParent).append("<span class='not'>not</span>") if neg

      if (node.temporal)
        $(elemParent).append("<span class='#{node.conjunction} temporal-operator'>#{node.title}</span><span class='block-down-arrow'></span>")

      builder.addParamItems(node,elemParent)
      if (i < items.length-1 and !node.temporal)
        next = items[i+1]
        conjunction = node.conjunction if !conjunction
        $(elemParent).append("<span class='conjunction "+conjunction+"'>"+conjunction+"</span>")
    )


  toggleDataCriteriaTree: (element) =>
    $(element.currentTarget).closest(".paramGroup").find("i").toggleClass("icon-chevron-right").toggleClass("icon-chevron-down")
    category = $(element.currentTarget).data('category');
    children = $(".#{category}_children")
    if (children.is(':visible'))
      children.hide("blind", { direction: "vertical" }, 500)
    else
      children.show("blind", { direction: "vertical" }, 500)

  addDataCriteria: (criteria) =>
    @data_criteria[criteria.id] = criteria = new bonnie.DataCriteria(criteria.id, criteria)
    $c = $('#dataCriteria>div.paramGroup[data-category="' + criteria.buildCategory() + '"]');
    if $c.length
      $e = $c.find('span')
      $e.text(parseInt($e.text()) + 1)
    else
      $c = $('
        <div class="paramGroup" data-category="' + criteria.buildCategory() + '">
          <div class="paramItem">
            <div class="paramText ' + criteria.buildCategory() + '">
              <label>' + criteria.standard_category + '(<span>1</span>)</label>
            </div>
          </div>
        </div>
      ').insertBefore('#dataCriteria .paramGroup[data-category=newDataCriteria]')
    $('
      <div class="paramItem">
        <div class="paramText">
          <label>' + criteria.title + (if criteria.status then ': '+ criteria.status else '') + '</label>
        </div>
      </div>
    ').appendTo(
      $(
        $c.nextUntil('#dataCriteria .paramGroup', '#dataCriteria .paramChildren')[0] ||
        $('<div class="paramChildren ' + criteria.buildCategory() + '_children" style="background-color: #F5F5F5;"></div>').insertAfter($c)
      )
    )

  delete_criteria_handler: ->
    find = (e, arr, key)->
     for k of arr
       return Number(k) if e[key] == arr[k][key]

    criteria_id = $(this).parentsUntil("#workspace").last().find("form > input[type=hidden][name=criteria_id]").val()
    precondition_id = $(this).parentsUntil("#workspace").last().find("form > input[type=hidden][name=precondition_id]").val()
    bonnie.template("confirm_criteria_delete",
      criteria_id: criteria_id
      precondition_id: precondition_id
    ).bind("hidden", ->
      $(this).remove()
    ).on("click", "input#confirm_criteria_delete_confirm", ->
      e = $("[data-precondition-id=" + precondition_id + "]").data("logic-id")
      if !e.parent.parent
        bonnie.builder.pushTree($.extend(e.parent, {children: []}));
      else if e.parent && e.parent.children.length <3
        bonnie.builder.pushTree(e.parent.parent.children.splice(find(e.parent, e.parent.parent.children, 'precondition_id'), 1, $.extend((if find(e, e.parent.children, 'precondition_id') then e.parent.children[0] else e.parent.children[1]), {parent: e.parent.parent}))[0])
      else
        bonnie.builder.pushTree(e.parent.children.splice(find(e, e.parent.children, 'precondition_id'), 1)[0])
      $('#confirm_criteria_delete').modal('hide')
      $('#workspace').empty()
      bonnie.builder._bindClickHandler()
    ).appendTo(document.body).modal()

  add_new_criteria: ->
    bonnie.template('data_criteria_new').appendTo(document.body).modal()
    $('#data_criteria_new select[name=category]').trigger('change')

class Page
  constructor: (data_criteria, measure_period, update_url, preconditions, fields, value_sets, statuses_by_definition) ->
    bonnie.builder = new bonnie.Builder(data_criteria, measure_period, preconditions, fields, value_sets, statuses_by_definition)
    bonnie.builder['update_url'] = update_url

  initialize: () =>
    $(document).on('click', '#dataCriteria .paramGroup', bonnie.builder.toggleDataCriteriaTree)
    $('.nav-tabs li').click((element) -> $('#workspace').empty() if !$(element.currentTarget).hasClass('active') )
