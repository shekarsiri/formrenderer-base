before ->
  $('body').html('<div data-formrenderer />')

describe 'Encapsulation', ->
  it 'does not share dependencies with the global namespace', ->
    expect(typeof window.ISOCountryNames).to.equal('undefined')
    expect(typeof window.FormRenderer).not.to.equal('undefined')

describe '#formatCents', ->
  before ->
    @fr = new FormRenderer Fixtures.FormRendererOptions.KITCHEN_SINK()

  it 'formats single-digit cents properly', ->
    price = @fr.response_fields.find (rf) -> rf.field_type == 'price'
    $cents = $('.fr_response_field_price input[data-rv-input="model.value.cents"]')
    $cents.val('3').trigger('blur')
    expect($cents.val()).to.equal('03')
    expect(price.get('value.cents')).to.equal('03')

describe 'adding and removing rows', ->
  before ->
    @fr = new FormRenderer Fixtures.FormRendererOptions.KITCHEN_SINK()

  it 'functions properly', ->
    $('button:contains("Next page")').click()
    table = @fr.response_fields.find (rf) -> rf.field_type == 'table'
    $('[data-rv-input="model.value.0.0"]').val('hi').trigger('input')
    expect(_.size(table.get('value')[0])).to.eql 2
    expect($('[data-rv-input="model.value.0.2"]').length).to.eql 0
    $('.js-add-row').click()
    expect($('[data-rv-input="model.value.0.2"]').length).to.eql 1
    $('[data-rv-input="model.value.0.2"]').val('hi').trigger('input')
    expect(_.size(table.get('value')[0])).to.eql 3
    $('.js-remove-row').click()
    expect(_.size(table.get('value')[0])).to.eql 2

describe 'state', ->
  before ->
    @fr = new FormRenderer Fixtures.FormRendererOptions.LOADED()

  describe 'hasChanges', ->
    it 'initially does not have changes', ->
      expect(@fr.state.get('hasChanges')).to.equal(false)

    describe 'after change event is fired', ->
      before ->
        @fr.response_fields.trigger('change:value')

      it 'has changes', ->
        expect(@fr.state.get('hasChanges')).to.equal(true)

describe 'handling blank forms', ->
  it 'submits a blank form', ->
    @fr = new FormRenderer Fixtures.FormRendererOptions.BLANK()
    @fr.submit = sinon.spy()
    expect($('[data-js-back]').length).to.equal(0)
    $('button:contains("Submit")').click()
    expect(@fr.submit).to.have.been.called

  it 'submits a blank form (with identification)', ->
    @fr = new FormRenderer Fixtures.FormRendererOptions.BLANK_IDENTIFIED()
    @fr.submit = sinon.spy()
    expect($('[data-js-back]').length).to.equal(0)
    $('input[type=text]').val('asdf@asdf.com') # fill in name *and* email
    $('button:contains("Submit")').click()
    expect(@fr.submit).to.have.been.called

describe '#loadFromServer', ->
  beforeEach ->
    @server = sinon.fakeServer.create()

  afterEach ->
    @server.restore()

  it 'loads just the project', ->
    @fr = new FormRenderer Fixtures.FormRendererOptions.RESPONSE_LOADED()

    @server.requests[0].respond 200, { "Content-Type": "application/json" }, JSON.stringify(
      project:
        id: 1
        response_fields: [ _.clone(Fixtures.RESPONSE_FIELD) ]
    )

    expect($('input[type=text]').val()).to.equal('hey')

  it 'loads just the draft', ->
    @fr = new FormRenderer Fixtures.FormRendererOptions.PROJECT_LOADED()

    @server.requests[0].respond 200, { "Content-Type": "application/json" }, JSON.stringify(
      response:
        id: 'xxx'
        responses:
          '1': 'Adam'
    )

    expect($('input[type=text]').val()).to.equal('Adam')

  it 'loads both project and draft', ->
    @fr = new FormRenderer Fixtures.FormRendererOptions.NOT_LOADED()

    @server.requests[0].respond 200, { "Content-Type": "application/json" }, JSON.stringify(
      response:
        id: 'xxx'
        responses:
          '1': 'Adam'
      project:
        id: 1
        response_fields: [ _.clone(Fixtures.RESPONSE_FIELD) ]
    )

    expect($('label').text()).to.have.string('Name')
    expect($('input[type=text]').val()).to.equal('Adam')

  it 'removes the draft ID on error', ->
    @fr = new FormRenderer Fixtures.FormRendererOptions.PROJECT_LOADED()

    cookieSpy =
      remove: sinon.spy()

    window.Cookies = cookieSpy

    @server.requests[0].respond 400, { "Content-Type": "application/json" }, JSON.stringify({})

    expect(cookieSpy.remove).to.have.been.called

describe '#submit', ->
  before ->
    @fr = new FormRenderer Fixtures.FormRendererOptions.LOADED()

  it 'does not save while uploads are in progress', ->
    FormRenderer::save = sinon.spy()
    @fr.requests = 1
    @fr.submit()
    expect(FormRenderer::save).to.not.have.been.called

  it 'saves if uploads are not in progress', ->
    FormRenderer::save = sinon.spy()
    @fr.requests = 0
    @fr.submit()
    expect(FormRenderer::save).to.have.been.called

describe 'options', ->
  describe 'enablePages', ->
    it 'is enabled by default', ->
      @fr = new FormRenderer Fixtures.FormRendererOptions.KITCHEN_SINK()
      expect($('[data-activate-page]').length).to.not.equal(0)

    it 'disables pages', ->
      @fr = new FormRenderer _.extend({}, Fixtures.FormRendererOptions.KITCHEN_SINK(), enablePages: false)
      expect($('[data-activate-page]').length).to.equal(0)

  describe 'validateImmediately', ->
    it 'is false by default', ->
      @fr = new FormRenderer Fixtures.FormRendererOptions.KITCHEN_SINK()
      expect($('.fr_error_alert_bar').length).to.equal(0)

    it 'validates immediately', ->
      @fr = new FormRenderer _.extend({}, Fixtures.FormRendererOptions.KITCHEN_SINK(), validateImmediately: true)
      expect($('.fr_error_alert_bar').length).to.not.equal(0)

describe 'number field classes', ->
  it 'functions properly', ->
    expectations = {
      one_three: [
        ['9', false]
        ['9', true]
        ['900', true]
      ]
      four_six: [
        ['90', false]
        ['999', false]
        ['123000.00', true]
        ['', true]
      ]
      seven_plus: [
        ['', false]
        [undefined, false]
      ]
    }

    for className, examples of expectations
      for example in examples
        @fr = new FormRenderer(
          project_id: 'dummy_val'
          response_fields: [
            field_type: 'number'
            max: example[0]
            integer_only: example[1]
          ]
          response:
            id: 'xxx'
            responses: {}
        )

        expect($(".size_#{className}").length).to.eql 1

# Need to mock AJAX requests for these...
describe '#save', ->
  it 'handles additional changes while saving'
  it 'sets state on success'
  it 'sets state on error'

describe 'translated content', ->
  it 'translates properly', ->
    @fr = new FormRenderer
      project_id: 'dummy_val'
      response_fields: [
        field_type: 'checkboxes'
        options: [
          label: 'check1'
          translated_label: 'check2'
        ]
      ,
        field_type: 'dropdown'
        options: [
          label: 'drop1'
          translated_label: 'drop2'
        ]
      ,
        field_type: 'radio'
        options: [
          label: 'rad1'
          translated_label: 'rad2'
        ]
      ,
        field_type: 'table'
        columns: [
          label: 'col1'
          translated_label: 'col2'
        ]
      ]
      response:
        id: 'xxx'
        responses: {}

    expect($("label:contains('check2')").length).to.eql 1
    expect($("option:contains('drop2')").length).to.eql 1
    expect($("label:contains('rad2')").length).to.eql 1
    expect($("th:contains('col2')").length).to.eql 1
