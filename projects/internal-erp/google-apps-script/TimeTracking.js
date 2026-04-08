/**
 * Main application logic and UI rendering for the Expertflow Time Tracker Add-on.
 */

/**
 * Triggered when a Calendar event is opened.
 * @param {Object} e - Event object
 * @returns {CardService.Card} The UI to display.
 */
function onCalendarEventOpen(e) {
  const calendarId = e.calendar.calendarId;
  const eventId = e.calendar.id;
  
  if (!eventId) {
    return createErrorCard('Please select a specific event to log time.');
  }
  
  // 1. Get User Email and ID
  const email = Session.getActiveUser().getEmail();
  
  try {
    const employeeId = getEmployeeId(email);
    
    if (!employeeId) {
      return createErrorCard(`Employee record not found for email: ${email}`);
    }
    
    // 2. Extract Event Details via CalendarApp API
    let title = 'Untitled Event';
    let startTime, endTime;
    
    // Try to get event details from the Calendar API
    const calendar = CalendarApp.getCalendarById(calendarId);
    if (calendar) {
      const calEvent = calendar.getEventById(eventId);
      if (calEvent) {
        title = calEvent.getTitle() || 'Untitled Event';
        startTime = calEvent.getStartTime();
        endTime = calEvent.getEndTime();
      }
    }
    
    // Fallback: try the event object directly (some trigger types include this)
    if (!startTime && e.calendar && e.calendar.startTime) {
      if (e.calendar.startTime.msSinceEpoch) {
        startTime = new Date(e.calendar.startTime.msSinceEpoch);
      } else {
        startTime = new Date(e.calendar.startTime);
      }
      if (e.calendar.endTime) {
        if (e.calendar.endTime.msSinceEpoch) {
          endTime = new Date(e.calendar.endTime.msSinceEpoch);
        } else {
          endTime = new Date(e.calendar.endTime);
        }
      }
      title = e.calendar.title || title;
    }
    
    if (!startTime || !endTime) {
      return createErrorCard('Could not read event details. Please ensure the event has a start and end time.');
    }
    
    const startTimeMs = startTime.getTime();
    const endTimeMs = endTime.getTime();
    
    const eventDetails = {
      title: title,
      startTime: startTime.toISOString(),
      endTime: endTime.toISOString(),
      duration: endTimeMs - startTimeMs,
      employeeId: employeeId
    };
    
    // 3. Render the Project Selection Card
    return buildProjectSelectionCard(eventDetails);
    
  } catch (error) {
    console.error(error);
    return createErrorCard('An error occurred: ' + error.message);
  }
}

/**
 * Builds the UI for selecting a project.
 * @param {Object} eventDetails - The pre-extracted details of the calendar event.
 * @returns {CardService.Card}
 */
function buildProjectSelectionCard(eventDetails) {
  const builder = CardService.newCardBuilder()
    .setName('ProjectSelection')
    .setHeader(CardService.newCardHeader()
      .setTitle('Log Time: ' + eventDetails.title)
      .setSubtitle(formatDateRange(new Date(eventDetails.startTime), new Date(eventDetails.endTime))));
      
  const section = CardService.newCardSection();
  
  // Pass event state as a hidden field (no title to minimize visibility)
  section.addWidget(CardService.newTextInput()
    .setFieldName('eventState')
    .setTitle(' ')
    .setValue(JSON.stringify(eventDetails))
  );

  // Description Input
  section.addWidget(CardService.newTextInput()
    .setFieldName('description')
    .setTitle('Description')
    .setValue(eventDetails.title)
    .setMultiline(true)
  );

  // Project Dropdown
  const projectSelection = CardService.newSelectionInput()
    .setType(CardService.SelectionInputType.DROPDOWN)
    .setTitle('Select Project')
    .setFieldName('projectId');

  // Try to get frequently-used projects first
  let topProjects = [];
  try {
    topProjects = getTopProjects(eventDetails.employeeId);
  } catch(e) { /* ignore */ }

  if (topProjects.length > 0) {
    topProjects.forEach((proj, idx) => {
      projectSelection.addItem(proj.name, proj.id.toString(), idx === 0);
    });
    // Add separator and rest of active projects
    const allProjects = searchActiveProjects('');
    const topIds = topProjects.map(p => p.id);
    allProjects.forEach(proj => {
      if (!topIds.includes(proj.id)) {
        projectSelection.addItem(proj.name, proj.id.toString(), false);
      }
    });
  } else {
    projectSelection.addItem('-- Select a Project --', '', false);
    const activeProjects = searchActiveProjects('');
    activeProjects.forEach(proj => {
      projectSelection.addItem(proj.name, proj.id.toString(), false);
    });
  }

  section.addWidget(projectSelection);

  // Submit Button
  const submitAction = CardService.newAction()
    .setFunctionName('handleConfirmTimeLog');
    
  const button = CardService.newTextButton()
    .setText('Review & Log Time')
    .setOnClickAction(submitAction)
    .setTextButtonStyle(CardService.TextButtonStyle.FILLED);
    
  section.addWidget(CardService.newButtonSet().addButton(button));
  
  builder.addSection(section);
  return builder.build();
}

/**
 * Callback for the AutoComplete suggestion.
 * @param {Object} e - Event data containing form inputs
 */
function onSearchProjectSuggestions(e) {
  const query = e.formInput.projectSearch || '';
  const suggestions = CardService.newSuggestions();
  
  if (query.trim().length > 0) {
    const activeProjects = searchActiveProjects(query);
    activeProjects.forEach(proj => {
      // Suggestion format: "Project Name (ID:123)"
      suggestions.addSuggestion(`${proj.name} (ID:${proj.id})`);
    });
  } else {
    // Show top projects if query is empty
    if (e.parameters && e.parameters.employeeId) {
       const top = getTopProjects(parseInt(e.parameters.employeeId));
       top.forEach(proj => suggestions.addSuggestion(`${proj.name} (ID:${proj.id})`));
    }
  }

  return CardService.newSuggestionsResponseBuilder()
    .setSuggestions(suggestions)
    .build();
}

/**
 * Interstitial confirmation card before sending data
 */
function handleConfirmTimeLog(e) {
  const formInput = e.formInput;
  const eventDetails = JSON.parse(formInput.eventState);
  
  const description = formInput.description;
  const projectId = formInput.projectId;
  
  if (!projectId) {
     return createErrorCard('Please select a project.');
  }
  
  // Construct the final data object
  const actionData = {
    description: description,
    startDateTime: eventDetails.startTime,
    endDateTime: eventDetails.endTime,
    employeeId: eventDetails.employeeId,
    projectId: projectId,
    hoursWorked: millisToIntervalString(eventDetails.duration)
  };
  
  // Return the confirmation UI
  const builder = CardService.newCardBuilder()
    .setHeader(CardService.newCardHeader().setTitle('Confirm Logging'));
    
  const section = CardService.newCardSection()
    .addWidget(CardService.newKeyValue().setTopLabel('Project ID').setContent(projectId.toString()))
    .addWidget(CardService.newKeyValue().setTopLabel('Hours').setContent(actionData.hoursWorked))
    .addWidget(CardService.newKeyValue().setTopLabel('Description').setContent(description));
    
  const submitAction = CardService.newAction()
    .setFunctionName('executeTimeLog')
    .setParameters({ payload: JSON.stringify(actionData) });
    
  const confirmBtn = CardService.newTextButton()
    .setText('Submit to ERP')
    .setOnClickAction(submitAction)
    .setTextButtonStyle(CardService.TextButtonStyle.FILLED);
    
  section.addWidget(CardService.newButtonSet().addButton(confirmBtn));
  
  return builder.addSection(section).build();
}

/**
 * Action to actually write to the database
 */
function executeTimeLog(e) {
  try {
    const payload = JSON.parse(e.parameters.payload);
    
    // Check if hoursWorked is 0
    if (payload.hoursWorked === '00:00:00') {
      return CardService.newActionResponseBuilder()
        .setNotification(CardService.newNotification()
          .setText('Cannot log 0 hours. Please check event duration.'))
        .build();
    }
    
    const success = insertTimeEntry(payload);
    
    if (success) {
      return CardService.newActionResponseBuilder()
        .setNotification(CardService.newNotification()
          .setText('Time logged successfully!'))
        .setNavigation(CardService.newNavigation().popToRoot())
        .build();
    } else {
       throw new Error('Insert failed - no rows affected.');
    }
  } catch (error) {
     console.error(error);
     return CardService.newActionResponseBuilder()
        .setNotification(CardService.newNotification()
          .setText(`Failed to log time: ${error.message}`))
        .build();
  }
}

/**
 * Standard error card UI
 */
function createErrorCard(message) {
  const section = CardService.newCardSection()
    .addWidget(CardService.newTextParagraph().setText(message));
    
  return CardService.newCardBuilder()
    .setHeader(CardService.newCardHeader().setTitle('Error'))
    .addSection(section)
    .build();
}

/**
 * Homepage trigger (fallback when not inside an event)
 */
function onHomepage(e) {
  const section = CardService.newCardSection()
    .addWidget(CardService.newTextParagraph()
      .setText('Welcome to the Expertflow Time Tracker.\n\nPlease open a calendar event to log time against it.'));
      
  return CardService.newCardBuilder()
    .setHeader(CardService.newCardHeader().setTitle('Time Tracker'))
    .addSection(section)
    .build();
}

/**
 * Format a human-readable date range
 */
function formatDateRange(start, end) {
  const opts = { month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit' };
  return `${start.toLocaleDateString(undefined, opts)} - ${end.toLocaleTimeString(undefined, {hour: 'numeric', minute: '2-digit'})}`;
}
