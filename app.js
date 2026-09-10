(function () {
  "use strict";
  angular
    .module("dfmApp", [])
    .directive("falconSelect2", function ($timeout) {
      return {
        restrict: "A",
        require: "ngModel",
        link: function (scope, element, attributes, ngModel) {
          $timeout(function () {
            element.select2({ width: "100%", placeholder: attributes.placeholder || "Select an option", allowClear: true });
          }, 0, false);
          // Angular's own select/ngOptions directive already listens for native "change" and updates
          // ngModel (translating ng-options "as" values correctly); do not also set the view value
          // from element.val() here - for ng-options selects that raw DOM value is an internal index,
          // not the real bound value, and overwriting ngModel with it corrupted budgetSourceId.
          scope.$on("$destroy", function () { if (element.data("select2")) element.select2("destroy"); });
        },
      };
    })
    .directive("fileChange", function () {
      return {
        restrict: "A",
        link: function (scope, element, attrs) {
          element.on("change", function () {
            var file = element[0].files && element[0].files[0];
            scope.$apply(function () { scope.$eval(attrs.fileChange, { $file: file }); });
          });
        },
      };
    })
    .controller("PortfolioController", function ($http, $timeout, $q) {
      var vm = this;
      vm.session = null;
      var rememberedEmail = rememberedLoginEmail();
      vm.auth = { mode: "login", email: rememberedEmail, rememberMe: !!rememberedEmail };
      vm.questions = [
        { securityQuestionId: 1, question: "What was the name of your first school?" },
        { securityQuestionId: 2, question: "In which city were you born?" },
        { securityQuestionId: 3, question: "What is the name of your childhood best friend?" },
      ];
      vm.today = new Date();
      vm.tab = "portfolio";
      vm.demo = true;
      vm.search = "";
      vm.statusFilter = "";
      vm.viewFilter = "all";
      vm.page = 1;
      vm.pageSize = 10;
      vm.pageCount = 1;
      vm.filteredCount = 0;
      vm.visibleProjects = [];
      vm.approvalItems = [];
      vm.approvalSearch = "";
      vm.approvalPage = 1;
      vm.approvalPageSize = 10;
      vm.approvalPageCount = 1;
      vm.approvalFilteredCount = 0;
      vm.visibleApprovalItems = [];
      vm.approvalSelection = {};
      vm.bulkDecisionItems = [];
      vm.decisionPetRows = [];
      vm.decisionSelection = {};
      vm.budgetLineVendorOptions = [];
      vm.budgetLineSpendDetails = [];
      vm.budgetSearch = "";
      vm.budgetPage = 1;
      vm.budgetPageSize = 10;
      vm.budgetPageCount = 1;
      vm.budgetFilteredCount = 0;
      vm.visibleBudgets = [];
      vm.roleUsers = [];
      vm.roleSearch = "";
      vm.roleFilter = "";
      vm.rolePage = 1;
      vm.rolePageSize = 20;
      vm.rolePageCount = 1;
      vm.roleFilteredCount = 0;
      vm.visibleRoleUsers = [];
      vm.roleSummary = { reviewer: 0, approver: 0, admin: 0 };
      vm.availableManagedRoles = ["Reviewer", "Approver", "Admin"];
      vm.departmentOptions = ["Business", "CET", "CIO Office", "Core", "CRM", "CTO", "Data", "EA&l", "EIS", "Governance", "Risk", "RTB", "Test Gov."];
      vm.unitTypeOptions = ["Nos", "Man Days", "Man Months", "Calender Months", "Fixed Scope"];
      vm.costTypeOptions = [
        "Hardware Purchase", "Hardware Rental", "Hardware AMC", "Software License Purchase", "Software License Subscription", "Software License AMC", "Escrow Agreement",
        "Project Management Services", "Business Analysis", "Architecture /Design", "SME Consulting Services", "Training", "in Months", "Application/Interface Development",
        "Software Customization", "Software Installation & Configuration", "Hardware Installation & Configuration", "Annual Support Operations", "OA Functional Testing",
        "QA Integration Testing", "QA Performance Testing", "QA Load Testing", "QA Test Automation", "SEC Penetration Testing", "UAT Functional Testing",
        "Professional Certification", "Quality Assurance (External)", "Travel & Accommodation", "Premises Rent", "Premises Fit out",
      ];
      vm.yearlyRecurrenceOptions = [1, 2, 3, 4, 5];
      vm.tabs = [
        { id: "portfolio", label: "Portfolio", icon: "layout-dashboard", roles: ["Requestor", "Reviewer", "Approver", "Admin", "Master"] },
        { id: "approvals", label: "Approvals", icon: "stamp", roles: ["Reviewer", "Approver"] },
        { id: "budgets", label: "CAPEX / OPEX", icon: "landmark", roles: ["Admin", "Master"] },
        { id: "roles", label: "Role management", icon: "users", roles: ["Admin", "Master"] },
        {
          id: "reports",
          label: "Management report",
          icon: "chart-no-axes-combined",
          roles: ["Admin", "Master"],
        },
      ];
      vm.navTabs = [];
      vm.stages = ["ITA", "Design", "Develop", "UAT", "Staging", "Live"];
      vm.metrics = {
        projectsRegistered: 4,
        activeProjects: 3,
        petsApproved: 3,
        petsOnTrack: 2,
        petsRejected: 1,
        invoicesRaised: 5,
        invoicesOutstanding: 3,
        invoicesSettled: 2,
        capexBudget: 5200000,
        capexUtilized: 2117500,
        opexBudget: 1750000,
        opexUtilized: 638000,
      };
      vm.budgets = [
        {
          budgetSourceId: 1,
          budgetType: "CAPEX",
          externalId: "IT_NP14_Sub_57_2025",
          description:
            "Core banking platform enhancements and security remediation",
          budget: 1750000,
          utilization: 1242630.78,
          availableBudget: 507369.22,
          requiresPet: true,
        },
        {
          budgetSourceId: 2,
          budgetType: "CAPEX",
          externalId: "IT_NP12_Sub_11_2025",
          description: "FinnOne delivery squad for risk and cards",
          budget: 2140876,
          utilization: 716217.25,
          availableBudget: 1424658.75,
        },
        {
          budgetSourceId: 3,
          budgetType: "OPEX",
          externalId: "OPEX-CET-0001",
          description: "MDS procurement of VDI licenses 2026",
          budget: 1200000,
          utilization: 84000,
          availableBudget: 1116000,
          requiresPet: true,
        },
        {
          budgetSourceId: 4,
          budgetType: "OPEX",
          externalId: "OPEX-CET-0002",
          description: "ATM CDM platform operational support",
          budget: 950000,
          utilization: 0,
          availableBudget: 950000,
        },
      ];
      vm.jira = [
        {
          jiraKey: "DIBITP-27312",
          summary:
            "Card upgrade, product change and limit change for credit cards",
          status: "Execution / Delivery",
          projectType: "Project",
          accountableExecLead: "Amit Saxena",
          accountableExec: "Zahoor Ul Islam",
          smeLead: "Amit Saxena",
          assignedProjectManager: "Syeda Areeba Tariq",
          projectRAG: "Green",
          platform: "FinOne",
          demandType: "Fast Track",
          requirements:
            "Automate contract communication and create a card upgrade workflow with product and limit-change controls.",
          portfolioExecutiveSummary:
            "Architecture design is complete. Integration discovery and delivery planning are in progress.",
        },
        {
          jiraKey: "DMGT-1011",
          summary: "Card upgrade",
          status: "Execution / Delivery",
          projectType: "Demand",
          accountableExecLead: "Amit Saxena",
          accountableExec: "Zahoor Ul Islam",
          smeLead: "Amit Saxena",
          assignedProjectManager: "Syeda Areeba Tariq",
          projectRAG: "Green",
          platform: "Cards",
          demandType: "Fast Track",
          requirements:
            "Increase cards revenue and simplify the customer upgrade process.",
          portfolioExecutiveSummary:
            "Demand accepted and linked to the delivery project.",
        },
        {
          jiraKey: "DMGT-433",
          summary: "Eleveo Call Recording System Upgrade",
          status: "Live",
          projectType: "Enhancement",
          accountableExecLead: "Wasim Akram",
          accountableExec: "Zahoor Ul Islam",
          smeLead: "Karthi Vasudevan",
          assignedProjectManager: "Muhammad Yahya Abdul Hayu",
          projectRAG: "Green",
          platform: "Call Center / IVR Services",
          demandType: "Strategic",
          requirements:
            "Upgrade obsolete RHEL and call recording components as part of OS remediation.",
          portfolioExecutiveSummary:
            "Development complete and service moved to live support.",
        },
      ];
      var invoices = [
        {
          invoiceId: 1001,
          vendorName: "Oracle LLC",
          justification: "Annual license",
          glNumber: "55001",
          invoiceNumber: "INV-2026-001",
          invoiceAmount: 15000,
          invoiceStatus: "Paid",
          paymentDate: new Date(2026, 7, 6),
        },
      ];
      var lines = [
        {
          budgetLineId: 1,
          vendor: "Oracle LLC",
          justification: "Annual platform license",
          cost: 150000,
          currency: "AED",
          glNumber: "55001",
          petReference: "PET-100",
          camId: "CAM-001",
          camStatus: "Approved",
          camComments: "Approved",
          lpoRequest: "LPO-100",
          lpoStatus: "Issued",
          lpoComments: "Completed",
          invoices: invoices,
        },
      ];
      vm.projects = [
        {
          projectId: 1,
          projectCode: "PRJ-000001",
          jiraKey: "DIBITP-27312",
          projectName: "Card upgrade and product change",
          projectType: "Project",
          accountableExecLead: "Amit Saxena",
          accountableExec: "Zahoor Ul Islam",
          smeLead: "Amit Saxena",
          projectSize: "Large",
          projectManager: "Syeda Areeba Tariq",
          requestorEmail: "cards.requestor@dfm.ae",
          requestorName: "Preview User",
          status: "Approved",
          createdUtc: new Date(2026, 7, 6),
          budgetType: "CAPEX",
          budgetSource: "IT_NP14_Sub_57_2025",
          budgetSourceId: 1,
          availableBudget: 507369.22,
          pets: [
            {
              petId: 1,
              code: "PET-2026-001",
              status: "Approved",
              requestedAmount: 150000,
              reviewerEmail: "Amit Saxena",
              approverEmail: "Zahoor Ul Islam",
              createdUtc: new Date(2026, 7, 5),
              spendItems: [],
              budgetLines: lines,
            },
          ],
        },
        {
          projectId: 2,
          projectCode: "PRJ-000002",
          jiraKey: "DMGT-433",
          projectName: "Eleveo Call Recording System Upgrade",
          projectType: "Enhancement",
          accountableExecLead: "Wasim Akram",
          accountableExec: "Ahmed Ali",
          smeLead: "Karthi Vasudevan",
          projectSize: "Medium",
          projectManager: "Muhammad Yahya Abdul Hayu",
          requestorEmail: "operations@dfm.ae",
          requestorName: "Operations Change",
          status: "Pending Approval",
          createdUtc: new Date(2026, 7, 18),
          budgetType: "OPEX",
          budgetSource: "OPEX-CET-0001",
          budgetSourceId: 3,
          availableBudget: 1116000,
          pets: [
            {
              petId: 2,
              code: "PET-2026-014",
              status: "Pending Approval",
              requestedAmount: 280000,
              reviewerEmail: "Wasim Akram",
              createdUtc: new Date(2026, 7, 19),
              spendItems: [],
              budgetLines: [],
            },
          ],
        },
        {
          projectId: 3,
          projectCode: "PRJ-000003",
          projectName: "Finance data retention controls",
          projectType: "Regulatory",
          accountableExecLead: "Nandi Kumar",
          accountableExec: "Sara Khan",
          smeLead: "Ravi Menon",
          projectSize: "Small",
          projectManager: "Hariprasath R",
          requestorEmail: "finance.change@dfm.ae",
          requestorName: "Finance Change",
          status: "Pending Review",
          createdUtc: new Date(2026, 7, 22),
          budgetType: "CAPEX",
          budgetSource: "IT_NP12_Sub_11_2025",
          budgetSourceId: 2,
          availableBudget: 1424658.75,
          requiresPet: true,
          pets: [
            {
              petId: 3,
              code: "PET-2026-018",
              status: "Pending Review",
              requestedAmount: 92500,
              createdUtc: new Date(2026, 7, 23),
              spendItems: [
                { spendItemId: 1, head: "Software", topic: "Retention controls", vendor: "Data Systems LLC", costType: "CAPEX", units: 5, unitPrice: 17500, currency: "AED", foreignAmount: 87500, aedAmount: 87500, contingencyPercent: 5, glNumber: "55001" },
              ],
              budgetLines: [],
            },
          ],
        },
        {
          projectId: 4,
          projectCode: "PRJ-000004",
          projectName: "ATM settlement reconciliation",
          projectType: "Operational",
          accountableExecLead: "Farah Noor",
          accountableExec: "Omar Salim",
          smeLead: "Khalid Rahman",
          projectSize: "Medium",
          projectManager: "Leena George",
          requestorEmail: "atm.ops@dfm.ae",
          requestorName: "ATM Operations",
          status: "Active",
          createdUtc: new Date(2026, 7, 25),
          budgetType: "OPEX",
          budgetSource: "OPEX-CET-0002",
          budgetSourceId: 4,
          availableBudget: 950000,
          requiresPet: false,
          pets: [],
        },
      ];

      vm.pageTitle = function () {
        return {
          portfolio: "Projects & financial workflow",
          approvals: "PET review & approval queue",
          budgets: "Budget source control",
          roles: "Role management",
          reports: "Management reporting",
        }[vm.tab];
      };
      vm.authTitle = function () { return { login: "Sign in", setup: "Create your password", reset: "Verify your identity", complete: "Choose a new password" }[vm.auth.mode]; };
      vm.authHelp = function () { return vm.auth.mode === "login" ? "Use your synchronized Active Directory email ID." : "This anonymous step is protected by your stored security challenge."; };
      vm.authAction = function () { return { login: "Sign in", setup: "Activate account", reset: "Verify answer", complete: "Reset password" }[vm.auth.mode]; };
      vm.enterPreview = function () { vm.session = { displayName: "Preview User", email: "cards.requestor@dfm.ae", initials: "PU", roles: ["Requestor", "Reviewer", "Approver", "Admin"] }; vm.demo = true; vm.roleUsers = previewRoleUsers(); updateNavigation(); vm.updateRoleView(); prepareProjects(); vm.updateView(); redraw(); };
      vm.signOut = function () { vm.session = null; vm.demo = true; resetLoginAuth(); sessionStorage.removeItem("dfmToken"); sessionStorage.removeItem("dfmSession"); delete $http.defaults.headers.common.Authorization; redraw(); };
      function normalizeAuthEmail(value) {
        return String(value || "").trim().replace(/[;,]+$/g, "").trim().toLowerCase();
      }
      vm.authenticate = function () {
        vm.auth.error = "";
        vm.auth.email = normalizeAuthEmail(vm.auth.email);
        if (!vm.auth.email || vm.auth.email.indexOf("@") < 1 || vm.auth.email.indexOf("@") === vm.auth.email.length - 1) { vm.auth.error = "Enter a valid email ID."; return; }
        var route = vm.auth.mode === "login" ? "login" : vm.auth.mode === "setup" ? "first-time-setup" : vm.auth.mode === "reset" ? "reset/challenge" : "reset/complete";
        $http.post("api/auth/" + route, vm.auth).then(function (response) {
          if (vm.auth.mode === "login") {
            if (response.data.requiresPasswordSetup) { vm.auth.mode = "setup"; return; }
            saveRememberedLogin();
            applySession(response.data, response.data.token);
            rememberSession(response.data);
            updateNavigation();
            loadDashboard();
            loadRoles();
          } else if (vm.auth.mode === "reset") { vm.auth.resetToken = response.data.resetToken; vm.auth.mode = "complete"; }
          else { vm.auth = { mode: "login", email: vm.auth.email, rememberMe: vm.auth.rememberMe }; notice("Password saved. Sign in to continue."); }
          redraw();
        }, function (response) { vm.auth.error = authResponseMessage(response, "Unable to complete this request."); });
      };
      function rememberedLoginEmail() {
        try { return localStorage.getItem("dfmRememberedEmail") || ""; }
        catch (ignore) { return ""; }
      }
      function saveRememberedLogin() {
        try {
          if (vm.auth.rememberMe && vm.auth.email) localStorage.setItem("dfmRememberedEmail", normalizeAuthEmail(vm.auth.email));
          else localStorage.removeItem("dfmRememberedEmail");
        } catch (ignore) { }
      }
      function resetLoginAuth() {
        var email = rememberedLoginEmail();
        vm.auth = { mode: "login", email: email, rememberMe: !!email };
      }
      function applySession(session, token) {
        vm.session = session || {};
        vm.demo = false;
        vm.session.roles = vm.session.roles || [];
        vm.session.initials = (vm.session.displayName || vm.session.email || "U").split(/\s+/).slice(0,2).map(function (part) { return part.charAt(0); }).join("").toUpperCase();
        if (token) {
          sessionStorage.setItem("dfmToken", token);
          $http.defaults.headers.common.Authorization = "Bearer " + token;
        }
      }
      function rememberSession(session) {
        try {
          var copy = angular.copy(session || {});
          delete copy.token;
          sessionStorage.setItem("dfmSession", angular.toJson(copy));
        } catch (ignore) { }
      }
      function restoreSession() {
        var token = sessionStorage.getItem("dfmToken");
        if (!token) return false;
        $http.defaults.headers.common.Authorization = "Bearer " + token;
        var loadedFromCache = false;
        try {
          var cached = angular.fromJson(sessionStorage.getItem("dfmSession") || "null");
          if (cached && cached.email) { loadedFromCache = true; applySession(cached, token); updateNavigation(); loadDashboard(); loadRoles(); }
        } catch (ignore) { }
        $http.get("api/auth/session").then(function (response) {
          applySession(response.data, token);
          rememberSession(response.data);
          updateNavigation();
          if (!loadedFromCache) { loadDashboard(); loadRoles(); }
          redraw();
        }, function () { vm.signOut(); });
        return true;
      }
      vm.hasRole = function (role) {
        var roles = vm.session && vm.session.roles || [];
        return roles.some(function (item) {
          return String(item).toLowerCase() === role.toLowerCase() ||
            (role === "Requestor" && String(item).toLowerCase() === "master") ||
            (role === "Requestor" && String(item).toLowerCase() === "admin") ||
            (role === "Admin" && String(item).toLowerCase() === "master") ||
            (role === "Master" && String(item).toLowerCase() === "admin");
        });
      };
      vm.can = function (action) {
        return action === "request" ? vm.hasRole("Requestor") : false;
      };
      function updateNavigation() {
        vm.navTabs = vm.tabs.filter(function (tab) { return !tab.roles || tab.roles.some(vm.hasRole); });
        if (!vm.navTabs.some(function (tab) { return tab.id === vm.tab; })) vm.tab = "portfolio";
      }
      vm.setTab = function (tabId) {
        vm.tab = tabId;
        if (tabId === "roles") loadRoles();
        vm.updateView(true);
        redraw();
      };
      vm.money = function (value) {
        var amount = Number(value) || 0;
        var formatted = new Intl.NumberFormat("en-AE", {
          maximumFractionDigits: 0,
        }).format(Math.abs(amount));
        return "AED " + (amount < 0 ? "-" : "") + formatted;
      };
      vm.amount = function (value) {
        return new Intl.NumberFormat("en-AE", {
          maximumFractionDigits: 2,
        }).format(Number(value) || 0);
      };
      vm.projectDisplayId = function (project) { return project && project.jiraKey ? project.jiraKey : project.projectCode; };
      vm.selectedBudgetSource = function () {
        return (vm.budgets || []).filter(function (b) {
          return b.budgetSourceId === vm.form.budgetSourceId;
        })[0];
      };
      vm.decisionCapexEditable = function () {
        return vm.form && vm.form.decision === "Approve" && vm.modal && (vm.modal.stage === "review" || vm.modal.stage === "approve");
      };
      vm.pendingWithName = function (project) {
        if (project.status === "Pending Review") return project.accountableExecLead;
        if (project.status === "Pending Approval") return project.accountableExec;
        return "";
      };
      function sameName(a, b) {
        return !!a && !!b && String(a).trim().toLowerCase() === String(b).trim().toLowerCase();
      }
      function sameEmail(a, b) {
        return !!a && !!b && String(a).trim().toLowerCase() === String(b).trim().toLowerCase();
      }
      function sameStatus(a, b) {
        return !!a && !!b && String(a).trim().toLowerCase() === String(b).trim().toLowerCase();
      }
      function existingPetVendor(pet) {
        if (!pet) return "";
        if (pet.vendorName || pet.VendorName) return pet.vendorName || pet.VendorName;
        if (pet.spendItems && pet.spendItems.length) return pet.spendItems[0].vendor || pet.spendItems[0].Vendor || "";
        if (pet.budgetLines && pet.budgetLines.length) return pet.budgetLines[0].vendor || pet.budgetLines[0].Vendor || "";
        return "";
      }
      vm.petVendor = existingPetVendor;
      function splitVendorNames(text) {
        var values = [];
        var value = String(text || "").trim();
        if (value) values.push(value);
        return values;
      }
      vm.petVendorOptions = function (pet) {
        var values = [];
        function addVendor(text) {
          splitVendorNames(text).forEach(function (value) {
            if (values.map(function (v) { return v.toLowerCase(); }).indexOf(value.toLowerCase()) < 0) values.push(value);
          });
        }
        ((pet && pet.spendItems) || []).forEach(function (item) {
          addVendor(item.vendor || item.Vendor);
        });
        if (!values.length) addVendor(pet && (pet.vendorName || pet.VendorName));
        return values;
      };
      function spendItemValue(item, names) {
        for (var index = 0; index < names.length; index++) {
          var value = item && item[names[index]];
          if (value) return value;
        }
        return null;
      }
      function uniqueSpendValues(items, names) {
        var values = [];
        (items || []).forEach(function (item) {
          var value = spendItemValue(item, names);
          value = value === null || angular.isUndefined(value) ? "" : String(value).trim();
          if (value && values.map(function (v) { return v.toLowerCase(); }).indexOf(value.toLowerCase()) < 0) values.push(value);
        });
        return values;
      }
      function budgetLineSpendItemsForVendor(pet, vendor) {
        var vendorKeys = splitVendorNames(vendor).map(function (value) { return value.toLowerCase(); });
        var items = (pet && pet.spendItems) || [];
        if (!vendorKeys.length) return vm.budgetLineVendorOptions.length ? [] : items;
        return items.filter(function (item) {
          return splitVendorNames(item.vendor || item.Vendor).some(function (itemVendor) { return vendorKeys.indexOf(itemVendor.toLowerCase()) >= 0; });
        });
      }
      function refreshBudgetLineSpendDetails() {
        vm.budgetLineSpendDetails = budgetLineSpendItemsForVendor(vm.selectedPet, vm.form && vm.form.vendor).map(normalizeSpendItem);
      }
      function budgetLineSpendAmount(item) {
        return parseNumericInput(item && (item.finalAedAmount || item.FinalAedAmount || item.finalAed || item.FinalAed)) || spendItemFinalAed(item || {});
      }
      function setBudgetLineDate(field, items, names) {
        var value = spendItemValue((items || []).filter(function (item) { return spendItemValue(item, names); })[0], names);
        vm.form[field] = value ? new Date(value) : null;
      }
      function applyBudgetLinePetValues() {
        if (!vm.form) return;
        refreshBudgetLineSpendDetails();
        if (vm.form.budgetLineId) return;
        var items = vm.budgetLineSpendDetails;
        vm.form.cost = null;
        vm.form.justification = "";
        vm.form.glNumber = "";
        vm.form.camId = "";
        vm.form.camStatus = "Raised to Vendor";
        vm.form.camComments = "";
        vm.form.lpoRequest = "";
        vm.form.lpoComments = "";
        vm.form.camCreatedDate = null;
        vm.form.camApprovedDate = null;
        vm.form.lpoIssueDate = null;
        var amount = items.reduce(function (total, item) { return total + budgetLineSpendAmount(item); }, 0);
        if (amount > 0) { vm.form.cost = Math.round(amount * 100) / 100; vm.form.currency = "AED"; }
        var currencies = uniqueSpendValues(items, ["currency", "Currency"]);
        if (!amount && currencies.length === 1) vm.form.currency = currencies[0];
        var descriptions = uniqueSpendValues(items, ["description", "Description"]);
        if (descriptions.length) vm.form.justification = descriptions.join(" | ");
        var glNumbers = uniqueSpendValues(items, ["glNumber", "GlNumber", "GLNumber"]);
        if (glNumbers.length) vm.form.glNumber = glNumbers.join(" | ");
        var camIds = uniqueSpendValues(items, ["camId", "CamId", "CAMId"]);
        if (camIds.length) vm.form.camId = camIds[0];
        var statuses = uniqueSpendValues(items, ["camStatus", "CamStatus", "status", "Status"]);
        if (statuses.length) vm.form.camStatus = statuses[0];
        var camComments = uniqueSpendValues(items, ["camComments", "CamComments"]);
        if (camComments.length) vm.form.camComments = camComments.join(" | ");
        var lpoRequests = uniqueSpendValues(items, ["lpoRequest", "LpoRequest", "lpoNumber", "LpoNumber"]);
        if (lpoRequests.length) vm.form.lpoRequest = lpoRequests[0];
        var lpoComments = uniqueSpendValues(items, ["lpoComments", "LpoComments"]);
        if (lpoComments.length) vm.form.lpoComments = lpoComments.join(" | ");
        setBudgetLineDate("camCreatedDate", items, ["camCreatedDate", "CamCreatedDate"]);
        setBudgetLineDate("camApprovedDate", items, ["camApprovedDate", "CamApprovedDate"]);
        setBudgetLineDate("lpoIssueDate", items, ["lpoIssueDate", "LpoIssueDate"]);
      }
      vm.onBudgetLineVendorChange = applyBudgetLinePetValues;
      function validateBudgetLineVendorSelection() {
        var selected = splitVendorNames(vm.form && vm.form.vendor);
        if (!selected.length) { noticeError("Vendor Name is required."); return false; }
        var allowed = vm.budgetLineVendorOptions || [];
        if (!allowed.length) { noticeError("Selected PET does not have an approved Vendor Name."); return false; }
        var match = allowed.filter(function (vendor) { return vendor.toLowerCase() === selected[0].toLowerCase(); })[0];
        if (!match) { noticeError("Vendor Name must be selected from the selected PET."); return false; }
        vm.form.vendor = match;
        return true;
      }
      vm.petSpendField = function (pet, field) {
        var values = [];
        ((pet && pet.spendItems) || []).forEach(function (item) {
          var value = item[field];
          if (value && values.indexOf(value) < 0) values.push(value);
        });
        return values.join(" | ") || "Not supplied";
      };
      // Login is by email, but JIRA only records the reviewer/approver's display name against
      // the project (AccountableExecLead/AccountableExec) - so match on Users.DisplayName, not email.
      vm.isReviewerFor = function (project) { return sameName(vm.session && vm.session.displayName, project.accountableExecLead); };
      vm.isApproverFor = function (project) { return sameName(vm.session && vm.session.displayName, project.accountableExec); };
      vm.isReviewerForPet = function (project, pet) { return sameEmail(vm.session && vm.session.email, pet && pet.reviewerEmail) || vm.isReviewerFor(project); };
      vm.isApproverForPet = function (project, pet) { return sameEmail(vm.session && vm.session.email, pet && pet.approverEmail) || vm.isApproverFor(project); };
      vm.setUploadFile = function (file) {
        vm.uploadFile = file;
        if (vm.modal && vm.modal.type === "pet") { redraw(); return; }
        vm.uploadPreview = [];
        vm.petUploadTotal = 0;
        if (!file || !vm.modal || vm.modal.type !== "upload" || vm.modal.kind !== "pet") { redraw(); return; }
        var projectId = vm.form.item && vm.form.item.projectId;
        if (!projectId) { noticeError("Unable to determine which project should receive these PET rows."); return; }
        var formData = new FormData();
        formData.append("file", file);
        $http.post("api/portfolio/bulk/pet/" + projectId + "/preview", formData, { transformRequest: angular.identity, headers: { "Content-Type": undefined } }).then(function (response) {
          vm.uploadPreview = preparePetUploadRows(response.data.rows || []);
          recalculatePetUploadTotal();
          redraw();
        }, function (response) {
          noticeError(responseMessage(response, "Unable to read PET upload file."));
          redraw();
        });
      };
      vm.importPetLines = function (file) {
        vm.petLineUploadFile = file;
        if (!file || !vm.selectedProject) { redraw(); return; }
        var formData = new FormData();
        formData.append("file", file);
        $http.post("api/portfolio/bulk/pet/" + vm.selectedProject.projectId + "/preview", formData, { transformRequest: angular.identity, headers: { "Content-Type": undefined } }).then(function (response) {
          var rows = preparePetUploadRows(response.data.rows || []);
          vm.uploadPreview = (vm.uploadPreview || []).concat(rows);
          vm.recalculateUploadPreview();
          notice(rows.length + " PET line row(s) imported for editing.");
          redraw();
        }, function (response) {
          noticeError(responseMessage(response, "Unable to import the PET Excel file."));
          redraw();
        });
      };
      vm.addPetUploadRow = function () {
        vm.openPetUploadRow();
      };
      vm.openPetUploadRow = function (row) {
        vm.petRowEditor = {
          original: row || null,
          row: preparePetUploadRow(row ? angular.copy(row) : {}, !row),
          isEdit: !!row,
        };
        if (!row) assignUniquePetReference(vm.petRowEditor.row);
        calculatePetUploadRow(vm.petRowEditor.row, false);
        redraw();
      };
      vm.closePetUploadRow = function () {
        vm.petRowEditor = null;
        redraw();
      };
      vm.recalculatePetRowEditor = function (deriveForeignAmount) {
        if (!vm.petRowEditor) return;
        calculatePetUploadRow(vm.petRowEditor.row, deriveForeignAmount);
        redraw();
      };
      vm.submitPetUploadRow = function () {
        if (!vm.petRowEditor) return;
        var row = vm.petRowEditor.row;
        assignUniquePetReference(row, vm.petRowEditor.original);
        if (!validatePetUploadRow(row, "popup", true, vm.petRowEditor.original)) return;
        if (vm.petRowEditor.original) angular.extend(vm.petRowEditor.original, row);
        else {
          vm.uploadPreview = vm.uploadPreview || [];
          vm.uploadPreview.push(row);
        }
        vm.petRowEditor = null;
        vm.recalculateUploadPreview();
        redraw();
      };
      vm.removePetUploadRow = function (row) {
        vm.uploadPreview = (vm.uploadPreview || []).filter(function (item) { return item !== row; });
        vm.recalculateUploadPreview();
        redraw();
      };
      vm.recalculatePetUploadRow = function (row, deriveForeignAmount) {
        calculatePetUploadRow(row, deriveForeignAmount);
        vm.recalculateUploadPreview();
      };
      vm.recalculateUploadPreview = function () {
        var sum = 0;
        (vm.uploadPreview || []).forEach(function (row) { calculatePetUploadRow(row, false); sum += parseNumericInput(row.finalAed); });
        vm.petUploadTotal = Math.round(sum * 100) / 100;
        vm.form.requestedAmount = Math.round(sum * 100) / 100;
      };
      function petReferenceExists(reference, excludeRow, extraRows) {
        var normalized = String(reference || "").trim().toLowerCase();
        if (!normalized) return false;
        var rows = (vm.uploadPreview || []).concat(extraRows || []);
        return rows.some(function (row) { return row !== excludeRow && String(row.petReference || "").trim().toLowerCase() === normalized; });
      }
      function normalizeSpendItem(item) {
        if (!item) return item;
        item.serialNo = item.serialNo || item.srNo || item.SrNo || "";
        if (item.lineDate && !angular.isDate(item.lineDate)) item.lineDate = new Date(item.lineDate);
        return item;
      }
      function generatedPetReference(excludeRow, extraRows) {
        var year = new Date().getFullYear();
        var reference;
        do {
          vm.petReferenceSequence = (vm.petReferenceSequence || 0) + 1;
          reference = "PET-" + year + "-" + String(Date.now()).slice(-5) + "-" + ("00" + vm.petReferenceSequence).slice(-3);
        } while (petReferenceExists(reference, excludeRow, extraRows));
        return reference;
      }
      function ensurePetReferenceNo() {
        vm.form = vm.form || {};
        var reference = String(vm.form.code || "").trim();
        if (!reference) {
          reference = generatedPetReference();
          vm.form.code = reference;
        }
        return reference;
      }
      function assignUniquePetReference(row) {
        row.petReference = ensurePetReferenceNo();
      }
      function petProjectExpenseHead(project) {
        return String(project && (project.budgetType || project.BudgetType) || "").toUpperCase();
      }
      vm.petProjectExpenseHead = function (project) {
        return petProjectExpenseHead(project || vm.selectedProject || (vm.form && vm.form.item)) || "Not supplied";
      };
      function applyPetProjectDefaults(row, project) {
        var head = petProjectExpenseHead(project || vm.selectedProject || (vm.form && vm.form.item));
        if (head) row.head = head;
        return row;
      }
      function preparePetUploadRows(rows) {
        var preparedRows = [];
        (rows || []).forEach(function (row) {
          var prepared = preparePetUploadRow(row, false);
          assignUniquePetReference(prepared);
          preparedRows.push(prepared);
        });
        return preparedRows;
      }
      function preparePetUploadRow(row, generateReference) {
        var project = vm.form.item || vm.selectedProject || {};
        var prepared = angular.extend({ projectId: vm.projectDisplayId(project), petReference: ensurePetReferenceNo(), serialNo: "", lineDate: null, lineId: "", department: "", currency: "AED", head: "", topic: "", vendor: "", description: "", costType: "", unitType: "", units: 1, unitPrice: 0, foreignAmount: 0, exchangeRate: 1, aedAmount: 0, contingencyPercent: 0, finalAed: 0, yearlyRecurrence: null, glNumber: "" }, normalizeSpendItem(row || {}));
        prepared.petReference = ensurePetReferenceNo();
        if (prepared.lineDate && !angular.isDate(prepared.lineDate)) prepared.lineDate = new Date(prepared.lineDate);
        applyPetProjectDefaults(prepared, project);
        if (!prepared.projectId) prepared.projectId = vm.projectDisplayId(project);
        if (prepared.spendItemId && prepared.unitPrice) {
          if ((prepared.currency || "AED").toUpperCase() === "AED") prepared.aedAmount = prepared.unitPrice;
          else prepared.foreignAmount = prepared.unitPrice;
        }
        if (generateReference) assignUniquePetReference(prepared);
        calculatePetUploadRow(prepared, !prepared.foreignAmount && !prepared.aedAmount);
        return prepared;
      }
      function validateNumericInput(value, label, allowBlank) {
        if (blankNumericInput(value)) {
          if (allowBlank) return true;
          noticeError(label + " is required.");
          return false;
        }
        if (/^-?(?:\d+\.?\d*|\.\d+)$/.test(String(value).replace(/,/g, "").trim())) return true;
        noticeError(label + " must be a numeric value.");
        return false;
      }
      function validOption(value, options) {
        return options.some(function (option) { return String(option).toLowerCase() === String(value || "").trim().toLowerCase(); });
      }
      function normalizeOption(value, options) {
        return options.filter(function (option) { return String(option).toLowerCase() === String(value || "").trim().toLowerCase(); })[0] || value;
      }
      function validatePetRequiredDropdowns(row, rowLabel) {
        if (!validOption(row && row.department, vm.departmentOptions)) { noticeError("Department is required on " + rowLabel + "."); return false; }
        if (!validOption(row && row.unitType, vm.unitTypeOptions)) { noticeError("Unit Type is required on " + rowLabel + "."); return false; }
        if (!validOption(row && row.costType, vm.costTypeOptions)) { noticeError("Cost Type is required on " + rowLabel + "."); return false; }
        if (!validOption(row && row.yearlyRecurrence, vm.yearlyRecurrenceOptions)) { noticeError("Yearly Recurrence is required on " + rowLabel + "."); return false; }
        row.department = normalizeOption(row.department, vm.departmentOptions);
        row.unitType = normalizeOption(row.unitType, vm.unitTypeOptions);
        row.costType = normalizeOption(row.costType, vm.costTypeOptions);
        row.yearlyRecurrence = parseNumericInput(row.yearlyRecurrence);
        return true;
      }
      function calculatePetUploadRow(row, deriveForeignAmount) {
        row.currency = (row.currency || "AED").toUpperCase();
        var units = parseNumericInput(row.units);
        var unitPrice = parseNumericInput(row.unitPrice);
        var foreignAmount = blankNumericInput(row.foreignAmount) ? 0 : parseNumericInput(row.foreignAmount);
        var aedAmount = blankNumericInput(row.aedAmount) ? 0 : parseNumericInput(row.aedAmount);
        var foreignBlank = blankNumericInput(row.foreignAmount);
        var aedBlank = blankNumericInput(row.aedAmount);
        if (deriveForeignAmount || !(foreignAmount > 0 || aedAmount > 0 || foreignBlank || aedBlank)) {
          if (row.currency === "AED") {
            row.aedAmount = unitPrice || "";
            aedAmount = unitPrice;
          } else {
            row.foreignAmount = unitPrice || "";
            foreignAmount = unitPrice;
          }
        }
        if (row.currency === "AED") {
          row.exchangeRate = 1;
          if (!aedAmount && !aedBlank) aedAmount = unitPrice;
          row.finalAed = units * (aedAmount || 0);
        } else {
          if (!foreignAmount && !foreignBlank) foreignAmount = unitPrice;
          row.finalAed = units * (foreignAmount || 0);
        }
        row.finalAed = Math.round(row.finalAed * 100) / 100;
      }
      function recalculatePetUploadTotal() {
        var total = 0;
        (vm.uploadPreview || []).forEach(function (row) { total += parseNumericInput(row.finalAed); });
        vm.petUploadTotal = Math.round(total * 100) / 100;
      }
      function validatePetUploadRow(row, rowLabel, requirePetReference, excludeRow) {
        applyPetProjectDefaults(row);
        assignUniquePetReference(row);
        calculatePetUploadRow(row, false);
        if (requirePetReference && !String(row.petReference || "").trim()) { noticeError("PET Reference No is required on " + rowLabel + "."); return false; }
        if (!String(row.vendor || "").trim()) { noticeError("Vendor is required on " + rowLabel + "."); return false; }
        if (!validatePetRequiredDropdowns(row, rowLabel)) return false;
        if (!validateNumericInput(row.units, "Units on " + rowLabel, false)) return false;
        if (!validateNumericInput(row.unitPrice, "Unit Price on " + rowLabel, false)) return false;
        if (!validateNumericInput(row.foreignAmount, "Amt. FCY on " + rowLabel, true)) return false;
        if (!validateNumericInput(row.aedAmount, "Amt. LCY on " + rowLabel, true)) return false;
        if (!validateNumericInput(row.contingencyPercent, "Contingency % on " + rowLabel, true)) return false;
        if (!(parseNumericInput(row.unitPrice) > 0)) { noticeError("Unit Price is required on " + rowLabel + "."); return false; }
        return true;
      }
      function validatePetUploadRows(requirePetReference) {
        if (!(vm.uploadPreview || []).length) { noticeError("Upload Excel/CSV rows or add a PET row before saving."); return false; }
        for (var rowIndex = 0; rowIndex < vm.uploadPreview.length; rowIndex++) {
          var row = vm.uploadPreview[rowIndex];
          if (requirePetReference) assignUniquePetReference(row);
          if (!validatePetUploadRow(row, "row " + (rowIndex + 1), requirePetReference, row)) return false;
        }
        recalculatePetUploadTotal();
        return true;
      }
      function petLinePayloads(petId) {
        return (vm.uploadPreview || []).map(function (row) {
          applyPetProjectDefaults(row);
          calculatePetUploadRow(row, false);
          var divisor = 1 + (parseNumericInput(row.contingencyPercent) / 100);
          var persistedAmount = divisor ? parseNumericInput(row.finalAed) / divisor : parseNumericInput(row.finalAed);
          return {
            spendItemId: row.spendItemId || null,
            petId: petId || row.petId || 0,
            serialNo: row.serialNo,
            lineDate: row.lineDate,
            lineId: row.lineId,
            department: row.department,
            head: row.head,
            topic: row.topic,
            vendor: row.vendor,
            description: row.description,
            costType: row.costType,
            unitType: row.unitType,
            units: parseNumericInput(row.units),
            unitPrice: parseNumericInput(row.unitPrice),
            currency: row.currency,
            foreignAmount: persistedAmount,
            exchangeRate: parseNumericInput(row.exchangeRate) || 1,
            aedAmount: persistedAmount,
            contingencyPercent: parseNumericInput(row.contingencyPercent),
            finalAed: parseNumericInput(row.finalAed),
            yearlyRecurrence: blankNumericInput(row.yearlyRecurrence) ? null : parseNumericInput(row.yearlyRecurrence),
            glNumber: row.glNumber,
          };
        });
      }
      function savePetUploadRows(projectId, onDone, reviewRequired) {
        if (!validatePetUploadRows(true)) return;
        var rows = (vm.uploadPreview || []).map(function (row) {
          var payload = angular.copy(row);
          payload.petReference = ensurePetReferenceNo();
          payload.serialNo = row.serialNo;
          payload.lineDate = row.lineDate;
          payload.lineId = row.lineId;
          payload.units = parseNumericInput(payload.units);
          payload.unitPrice = parseNumericInput(payload.unitPrice);
          payload.foreignAmount = parseNumericInput(payload.foreignAmount);
          payload.exchangeRate = parseNumericInput(payload.exchangeRate) || 1;
          payload.aedAmount = parseNumericInput(payload.aedAmount);
          payload.contingencyPercent = parseNumericInput(payload.contingencyPercent);
          payload.finalAed = parseNumericInput(payload.finalAed);
          payload.yearlyRecurrence = blankNumericInput(payload.yearlyRecurrence) ? null : parseNumericInput(payload.yearlyRecurrence);
          if (angular.isDefined(reviewRequired)) payload.reviewRequired = !!reviewRequired;
          return payload;
        });
        $http.post("api/portfolio/bulk/pet/" + projectId + "/rows", rows).then(function (response) {
          notice((response.data.imported || 0) + " PET row(s) saved.");
          vm.uploadFile = null;
          vm.close();
          loadDashboard().then(function () { if (onDone) onDone(); });
        }, function (response) {
          noticeError(responseMessage(response, "Unable to save PET rows."));
        });
      }
      vm.deleteProject = function (project) {
        if (!window.confirm("Delete project " + project.projectCode + "? This cannot be undone.")) return;
        $http.delete("api/portfolio/projects/" + project.projectId).then(function () {
          notice("Project deleted");
          loadDashboard();
        }, function (response) { noticeError((response.data && response.data.message) || "Unable to delete this project."); });
      };
      vm.deletePet = function (project, pet) {
        if (!window.confirm("Delete PET " + pet.code + "? This cannot be undone.")) return;
        $http.delete("api/portfolio/pets/" + pet.petId).then(function () {
          notice("PET deleted");
          refreshProjectPets(project.projectId, true);
          loadDashboard();
        }, function (response) { noticeError((response.data && response.data.message) || "Unable to delete this PET."); });
      };
      vm.deleteBudgetLine = function (project, line) {
        if (!window.confirm("Delete Budget Line " + (line.petReference || line.camId || line.budgetLineId) + "? This will also delete its invoices.")) return;
        $http.delete("api/portfolio/budget-lines/" + line.budgetLineId).then(function () {
          notice("Budget line deleted");
          refreshProjectPets(project.projectId, true);
          loadDashboard();
        }, function (response) { noticeError(responseMessage(response, "Unable to delete this Budget Line.")); });
      };
      function refreshProjectPets(projectId, expandRegardless, keepExpandedState) {
        var project = vm.projects.filter(function (p) { return p.projectId === projectId; })[0];
        if (!project) return $q.when();
        project.petsLoaded = false;
        return loadProjectPets(project, expandRegardless, keepExpandedState);
      }
      function refreshProjectsFromDatabase(projectIds) {
        var ids = [];
        (projectIds || []).forEach(function (projectId) {
          if (projectId && ids.indexOf(projectId) < 0) ids.push(projectId);
        });
        return loadDashboard().then(function () {
          return $q.all(ids.map(function (projectId) { return refreshProjectPets(projectId, true); }));
        });
      }
      // Computed once whenever jira/jiraPlan change (not called from the template) - calling this
      // from ng-repeat would rebuild new arrays/objects every digest and trigger an infinite digest loop.
      function computePlanGroups() {
        var byParent = {};
        (vm.jiraPlan || []).forEach(function (activity) {
          var key = activity.parentJiraID || "Unassigned";
          if (!byParent[key]) byParent[key] = [];
          byParent[key].push(activity);
        });
        return Object.keys(byParent).map(function (parentKey) {
          var parent = (vm.jira || []).filter(function (j) { return j.jiraKey === parentKey; })[0];
          return {
            parentKey: parentKey,
            parentName: parent ? parent.summary : parentKey,
            activities: byParent[parentKey],
          };
        });
      }
      vm.activityDuration = function (activity) {
        var start = activity.activityPlannedStartDate || activity.baselineStartDate;
        var end = activity.activityPlannedEndDate || activity.baselineEndDate;
        if (!start || !end) return "";
        var days = Math.round((new Date(end) - new Date(start)) / 86400000);
        return days >= 0 ? days + " days" : "";
      };
      vm.percent = function (value, total) {
        return total ? Math.round(((Number(value) || 0) * 100) / total) : 0;
      };
      function blankNumericInput(value) {
        return value === null || angular.isUndefined(value) || String(value).trim() === "";
      }
      function parseNumericInput(value) {
        if (blankNumericInput(value)) return 0;
        return Number(String(value).replace(/,/g, "")) || 0;
      }
      vm.statusClass = function (status) {
        var text = (status || "").toLowerCase();
        if (/approved|paid|settled|issued|active|live/.test(text))
          return "approved";
        if (/reject|blocked/.test(text)) return "rejected";
        if (/pending|outstanding|received|review|approval|sent back/.test(text))
          return "pending";
        return "neutral";
      };
      vm.pendingPet = function (project, status) {
        for (var index = 0; index < project.pets.length; index++) if (project.pets[index].status === status) return project.pets[index];
        return null;
      };
      vm.canAddBudgetLine = function (pet) { return pet && pet.status === "Approved"; };
      vm.canMaintainPet = function (pet) { return pet && (pet.status === "Pending Review" || pet.status === "Sent Back"); };
      vm.petForNewBudgetLine = function (project) {
        var pets = project && project.pets || [];
        for (var index = 0; index < pets.length; index++) if (vm.canAddBudgetLine(pets[index])) return pets[index];
        return null;
      };
      vm.petFinalAed = function (pet) {
        if (!pet.spendItems || !pet.spendItems.length) return parseNumericInput(pet.requestedAmount);
        return pet.spendItems.reduce(function (total, item) { return total + parseNumericInput(item.aedAmount) * (1 + parseNumericInput(item.contingencyPercent) / 100); }, 0);
      };
      vm.projectPetRequestTotal = function (project) {
        return ((project && project.pets) || []).reduce(function (total, pet) { return total + parseNumericInput(pet.requestedAmount); }, 0);
      };
      function petBudgetLineTotal(pet, excludeBudgetLineId) {
        return ((pet && pet.budgetLines) || []).reduce(function (total, line) {
          if (excludeBudgetLineId && String(line.budgetLineId) === String(excludeBudgetLineId)) return total;
          return total + parseNumericInput(line.cost);
        }, 0);
      }
      vm.petBudgetLineAvailable = function (pet, excludeBudgetLineId) {
        return Math.max(parseNumericInput(pet && pet.requestedAmount) - petBudgetLineTotal(pet, excludeBudgetLineId), 0);
      };
      function spendItemFinalAed(item) {
        var foreignAmount = spendForeignAmount(item);
        var aedAmount = spendAedAmount(item);
        return aedAmount * (1 + parseNumericInput(item.contingencyPercent) / 100);
      }
      vm.spendFinalAed = spendItemFinalAed;
      function spendForeignAmount(item) {
        return parseNumericInput(item && item.foreignAmount) || parseNumericInput(item && item.units) * parseNumericInput(item && item.unitPrice);
      }
      function spendAedAmount(item) {
        var foreignAmount = spendForeignAmount(item);
        var explicitAed = parseNumericInput(item && item.aedAmount);
        if (explicitAed) return explicitAed;
        var currency = String(item && item.currency || "AED").toUpperCase();
        var rate = currency === "AED" ? 1 : parseNumericInput(item && item.exchangeRate) || 1;
        return foreignAmount * rate;
      }
      vm.recalculateSpendForm = function () {
        if (!vm.form) return;
        var currency = String(vm.form.currency || "AED").toUpperCase();
        if (currency === "AED") vm.form.exchangeRate = 1;
        var rate = currency === "AED" ? 1 : parseNumericInput(vm.form.exchangeRate) || 1;
        var foreignAmount = spendForeignAmount(vm.form);
        vm.form.aedAmount = foreignAmount ? Math.round(foreignAmount * rate * 100) / 100 : "";
      };
      function petFinalAedWithSpend(pet, item) {
        var spendItemId = item && item.spendItemId;
        var existing = ((pet && pet.spendItems) || []).reduce(function (total, current) {
          if (spendItemId && String(current.spendItemId) === String(spendItemId)) return total;
          return total + spendItemFinalAed(current);
        }, 0);
        return existing + spendItemFinalAed(item || {});
      }
      function projectBudgetAmount(project) {
        return parseNumericInput(project && project.budget) || parseNumericInput(project && project.availableBudget);
      }
      vm.projectBudgetAmount = projectBudgetAmount;
      function validatePetRequestAmount(project, pet, requestedAmount) {
        requestedAmount = parseNumericInput(requestedAmount);
        var projectBudget = projectBudgetAmount(project);
        if (projectBudget > 0 && requestedAmount > projectBudget) {
          noticeError("PET Request amount exceeds the Project Budget. Project Budget: " + vm.money(projectBudget) + "; entered amount: " + vm.money(requestedAmount) + ".");
          return false;
        }
        var budgetLineTotal = petBudgetLineTotal(pet);
        if (pet && budgetLineTotal > requestedAmount) {
          noticeError("PET Request amount is below the existing Budget Line total for this PET Reference. Existing Budget Lines total: " + vm.money(budgetLineTotal) + "; entered PET amount: " + vm.money(requestedAmount) + ".");
          return false;
        }
        return true;
      }
      function validateBudgetLineAmount() {
        if (!validateNumericInput(vm.form && vm.form.cost, "Budget Line amount", false)) return false;
        var cost = parseNumericInput(vm.form && vm.form.cost);
        if (cost <= 0) { noticeError("A positive Budget Line amount is required."); return false; }
        vm.form.cost = cost;
        var available = parseNumericInput(vm.selectedPet && vm.selectedPet.requestedAmount) - petBudgetLineTotal(vm.selectedPet, vm.form && vm.form.budgetLineId);
        if (cost > available) {
          noticeError("Budget Line amount exceeds the Available PET Amount for PET Reference " + (vm.selectedPet && vm.selectedPet.code || "") + ". Available PET Amount: " + vm.money(Math.max(available, 0)) + "; entered amount: " + vm.money(cost) + ".");
          return false;
        }
        return true;
      }
      function validateSpendFormAmounts(form) {
        var currency = String(form && form.currency || "AED").toUpperCase();
        if (!validatePetRequiredDropdowns(form, "PET line item")) return false;
        if (!validateNumericInput(form && form.units, "Units", false)) return false;
        if (!validateNumericInput(form && form.unitPrice, "Unit price", false)) return false;
        if (!validateNumericInput(form && form.foreignAmount, "FCY amount", true)) return false;
        if (!validateNumericInput(form && form.exchangeRate, "Exchange rate", currency === "AED")) return false;
        if (!validateNumericInput(form && form.contingencyPercent, "Contingency %", true)) return false;
        return true;
      }
      function validateBudgetSourceAmounts(form) {
        if (!validateNumericInput(form && form.budget, "Budget", false)) return false;
        if (!validateNumericInput(form && form.utilization, "Utilization", false)) return false;
        if (!validateNumericInput(form && form.availableBudget, "Available budget", false)) return false;
        return true;
      }
      function projectHasStatus(project, pets, status) {
        if (!status) return true;
        if (sameStatus(project && project.status, status)) return true;
        if ((pets || []).some(function (pet) { return sameStatus(pet.status, status); })) return true;
        if (sameStatus(status, "Approved")) return Number(project && project.approvedPetCount) > 0;
        if (sameStatus(status, "Pending Review")) return Number(project && project.pendingReviewPetCount) > 0;
        if (sameStatus(status, "Pending Approval")) return Number(project && project.pendingApprovalPetCount) > 0;
        if (sameStatus(status, "Rejected")) return Number(project && project.rejectedPetCount) > 0;
        if (sameStatus(status, "Sent Back")) return Number(project && project.sentBackPetCount) > 0;
        return false;
      }
      vm.updateView = function (keepPage) {
        var query = vm.search.toLowerCase();
        var currentEmail = (vm.session && vm.session.email || "").toLowerCase();
        var currentName = (vm.session && vm.session.displayName || "").toLowerCase();
        var filtered = vm.projects.filter(function (p) {
          var pets = p.pets || [];
          var statusMatch = projectHasStatus(p, pets, vm.statusFilter);
          var isMine = (p.requestorEmail || "").toLowerCase() === currentEmail || (p.requestorName || "").toLowerCase() === currentName;
          var viewMatch = vm.viewFilter === "all" ||
            (vm.viewFilter === "my" && isMine) ||
            (vm.viewFilter === "jira" && !!p.jiraKey) ||
            (vm.viewFilter === "nonJira" && !p.jiraKey) ||
            (vm.viewFilter === "pendingReview" && pets.some(function (pet) { return pet.status === "Pending Review"; })) ||
            (vm.viewFilter === "pendingApproval" && pets.some(function (pet) { return pet.status === "Pending Approval"; })) ||
            (vm.viewFilter === "approved" && pets.some(function (pet) { return pet.status === "Approved" && (isMine || (pet.approverEmail || "").toLowerCase() === currentEmail); })) ||
            (vm.viewFilter === "reviewed" && pets.some(function (pet) { return !!pet.reviewedUtc; }));
          return (
            viewMatch &&
            statusMatch &&
            (!query ||
              [
                p.projectCode,
                p.jiraKey,
                p.projectName,
                p.accountableExecLead,
                p.requestorEmail,
              ]
                .join(" ")
                .toLowerCase()
                .indexOf(query) >= 0)
          );
        });
        vm.filteredCount = filtered.length;
        vm.pageCount = Math.max(1, Math.ceil(filtered.length / vm.pageSize));
        if (!keepPage || vm.page > vm.pageCount) vm.page = 1;
        var start = (vm.page - 1) * vm.pageSize;
        vm.visibleProjects = filtered.slice(start, start + vm.pageSize);
        vm.approvalItems = buildApprovalItems();
        vm.updateApprovalView(keepPage);
        vm.updateBudgetView(keepPage);
      };
      vm.changePage = function (page) { vm.page = Math.max(1, Math.min(vm.pageCount, page)); vm.updateView(true); };
      vm.changeApprovalPage = function (page) { vm.approvalPage = Math.max(1, Math.min(vm.approvalPageCount, page)); vm.updateApprovalView(true); };
      vm.changeBudgetPage = function (page) { vm.budgetPage = Math.max(1, Math.min(vm.budgetPageCount, page)); vm.updateBudgetView(true); };
      vm.changeRolePage = function (page) { vm.rolePage = Math.max(1, Math.min(vm.rolePageCount, page)); vm.updateRoleView(true); };
      function buildApprovalItems() {
        var result = [];
        var canReview = vm.hasRole("Reviewer");
        var canApprove = vm.hasRole("Approver");
        vm.projects.forEach(function (p) {
          var reviewPets = [];
          var approvePets = [];
          p.pets.forEach(function (pet) {
            if (pet.status === "Pending Review" && canReview && vm.isReviewerForPet(p, pet)) reviewPets.push(pet);
            if (pet.status === "Pending Approval" && canApprove && vm.isApproverForPet(p, pet)) approvePets.push(pet);
          });
          if (reviewPets.length) result.push({ project: p, pet: reviewPets[0], pets: reviewPets, petCount: reviewPets.length, requestedAmount: reviewPets.reduce(function (total, pet) { return total + (Number(pet.requestedAmount) || 0); }, 0), stage: "review", action: "Review" });
          if (approvePets.length) result.push({ project: p, pet: approvePets[0], pets: approvePets, petCount: approvePets.length, requestedAmount: approvePets.reduce(function (total, pet) { return total + (Number(pet.requestedAmount) || 0); }, 0), stage: "approve", action: "Approve" });
        });
        return result;
      }
      vm.updateApprovalView = function (keepPage) {
        var query = (vm.approvalSearch || "").toLowerCase();
        var filtered = (vm.approvalItems || []).filter(function (item) {
          return !query || [item.project.projectCode, item.project.jiraKey, item.project.projectName, item.project.projectType, (item.pets || []).map(function (pet) { return pet.code; }).join(" "), item.pet.status, item.project.budgetSource, item.project.requestorEmail, item.project.requestorName, item.pet.reviewerEmail, item.pet.approverEmail].join(" ").toLowerCase().indexOf(query) >= 0;
        });
        vm.approvalFilteredCount = filtered.length;
        vm.approvalPageCount = Math.max(1, Math.ceil(filtered.length / vm.approvalPageSize));
        if (!keepPage || vm.approvalPage > vm.approvalPageCount) vm.approvalPage = 1;
        var start = (vm.approvalPage - 1) * vm.approvalPageSize;
        vm.visibleApprovalItems = filtered.slice(start, start + vm.approvalPageSize);
      };
      function approvalSelectionKey(item) { return item && item.pet ? String(item.pet.petId) : ""; }
      vm.isApprovalSelected = function (item) { return !!vm.approvalSelection[approvalSelectionKey(item)]; };
      vm.toggleApprovalSelection = function (item) {
        var key = approvalSelectionKey(item);
        if (!key) return;
        if (vm.approvalSelection[key]) delete vm.approvalSelection[key];
        else vm.approvalSelection[key] = item.stage;
      };
      vm.selectedApprovalItems = function (stage) {
        return (vm.approvalItems || []).filter(function (item) {
          return vm.approvalSelection[approvalSelectionKey(item)] && (!stage || item.stage === stage);
        });
      };
      vm.selectedApprovalCount = function (stage) { return vm.selectedApprovalItems(stage).length; };
      vm.clearApprovalSelection = function () { vm.approvalSelection = {}; };
      function canSelectDecisionPet(project, pet, stage) {
        if (!project || !pet) return false;
        if (stage === "review") return pet.status === "Pending Review" && vm.isReviewerForPet(project, pet);
        return pet.status === "Pending Approval" && vm.isApproverForPet(project, pet);
      }
      function decisionSelectionKey(pet) { return pet ? String(pet.petId) : ""; }
      function rebuildBulkDecisionItems(stage) {
        var decisionStage = stage || (vm.modal && vm.modal.stage);
        vm.bulkDecisionItems = (vm.decisionPetRows || []).filter(function (item) {
          return vm.decisionSelection[decisionSelectionKey(item.pet)] && canSelectDecisionPet(item.project, item.pet, decisionStage);
        });
        if (vm.form) {
          vm.form.requestedAmount = vm.bulkDecisionItems.reduce(function (total, item) { return total + (Number(item.pet.requestedAmount) || 0); }, 0);
          vm.form.code = vm.bulkDecisionItems.length + " PET" + (vm.bulkDecisionItems.length === 1 ? "" : "s") + " selected";
        }
      }
      function buildDecisionPetRows(project, selectedPet, stage) {
        vm.decisionSelection = {};
        vm.decisionPetRows = ((project && project.pets) || []).map(function (pet) {
          if (selectedPet && pet.petId === selectedPet.petId && canSelectDecisionPet(project, pet, stage)) vm.decisionSelection[decisionSelectionKey(pet)] = true;
          return { project: project, pet: pet };
        });
        rebuildBulkDecisionItems(stage);
      }
      vm.canSelectDecisionPet = function (item) { return item && canSelectDecisionPet(item.project, item.pet, vm.modal && vm.modal.stage); };
      vm.isDecisionPetSelected = function (item) { return !!vm.decisionSelection[decisionSelectionKey(item && item.pet)]; };
      vm.toggleDecisionPet = function (item) {
        if (!vm.canSelectDecisionPet(item)) return;
        var key = decisionSelectionKey(item.pet);
        if (vm.decisionSelection[key]) delete vm.decisionSelection[key];
        else vm.decisionSelection[key] = true;
        rebuildBulkDecisionItems();
      };
      function decisionSelectableItems() {
        return (vm.decisionPetRows || []).filter(function (item) { return vm.canSelectDecisionPet(item); });
      }
      vm.decisionSelectableCount = function () { return decisionSelectableItems().length; };
      vm.allDecisionPetsSelected = function () {
        var items = decisionSelectableItems();
        return !!items.length && items.every(function (item) { return vm.isDecisionPetSelected(item); });
      };
      vm.toggleAllDecisionPets = function () {
        var items = decisionSelectableItems();
        if (!items.length) return;
        var selectAll = !vm.allDecisionPetsSelected();
        items.forEach(function (item) {
          var key = decisionSelectionKey(item.pet);
          if (selectAll) vm.decisionSelection[key] = true;
          else delete vm.decisionSelection[key];
        });
        rebuildBulkDecisionItems();
      };
      vm.selectedDecisionCount = function () { return vm.bulkDecisionItems.length; };
      vm.updateBudgetView = function (keepPage) {
        var query = (vm.budgetSearch || "").toLowerCase();
        var filtered = (vm.budgets || []).filter(function (budget) {
          return !query || [budget.budgetType, budget.externalId, budget.description].join(" ").toLowerCase().indexOf(query) >= 0;
        });
        vm.budgetFilteredCount = filtered.length;
        vm.budgetPageCount = Math.max(1, Math.ceil(filtered.length / vm.budgetPageSize));
        if (!keepPage || vm.budgetPage > vm.budgetPageCount) vm.budgetPage = 1;
        var start = (vm.budgetPage - 1) * vm.budgetPageSize;
        vm.visibleBudgets = filtered.slice(start, start + vm.budgetPageSize);
      };
      vm.updateRoleView = function (keepPage) {
        var query = (vm.roleSearch || "").toLowerCase();
        vm.roleSummary = { reviewer: 0, approver: 0, admin: 0 };
        (vm.roleUsers || []).forEach(function (user) {
          if (user.elevatedRole === "Reviewer") vm.roleSummary.reviewer++;
          if (user.elevatedRole === "Approver") vm.roleSummary.approver++;
          if (user.elevatedRole === "Admin") vm.roleSummary.admin++;
        });
        var filtered = (vm.roleUsers || []).filter(function (user) {
          var queryMatch = !query || [user.displayName, user.email, user.roleList].join(" ").toLowerCase().indexOf(query) >= 0;
          var roleMatch = !vm.roleFilter || user.elevatedRole === vm.roleFilter || (vm.roleFilter === "Requestor" && !user.elevatedRole);
          return queryMatch && roleMatch;
        });
        vm.roleFilteredCount = filtered.length;
        vm.rolePageCount = Math.max(1, Math.ceil(filtered.length / vm.rolePageSize));
        if (!keepPage || vm.rolePage > vm.rolePageCount) vm.rolePage = 1;
        var start = (vm.rolePage - 1) * vm.rolePageSize;
        vm.visibleRoleUsers = filtered.slice(start, start + vm.rolePageSize);
      };
      function prepareProjects() {
        if (vm.demo) vm.budgetUsage = [];
        vm.projects.forEach(function (project) {
          if (typeof project.petsLoaded === "undefined") project.petsLoaded = angular.isArray(project.pets);
          project.pets = project.pets || [];
          project.budgetLines = project.budgetLines || [];
          project.petCount = project.petsLoaded ? project.pets.length : Number(project.petCount) || 0;
          project.approvedPetCount = project.petsLoaded ? project.pets.filter(function (pet) { return pet.status === "Approved"; }).length : Number(project.approvedPetCount) || 0;
          project.spendRequestCount = Number(project.spendRequestCount) || 0;
          project.budgetLineCount = Number(project.budgetLineCount) || 0;
          project.invoiceCount = Number(project.invoiceCount) || 0;
          if (!project.petsLoaded) return;
          project.spendRequestCount = 0;
          project.budgetLineCount = 0;
          project.invoiceCount = 0;
          project.budgetLines = [];
          project.pets.forEach(function (pet) {
            pet.spendItems = pet.spendItems || [];
            pet.budgetLines = pet.budgetLines || [];
            if (pet.spendItems.length) pet.requestedAmount = vm.petFinalAed(pet);
            project.spendRequestCount += pet.spendItems.length;
            project.budgetLineCount += pet.budgetLines.length;
            pet.budgetLines.forEach(function (line) { line.invoices = line.invoices || []; line.petCode = pet.code; project.budgetLines.push(line); project.invoiceCount += line.invoices.length; });
            if (vm.demo && project.budgetType === "CAPEX" && pet.status === "Approved") vm.budgetUsage.push({ budgetSource: project.budgetSource, projectName: project.projectName, petCode: pet.code, amount: pet.requestedAmount });
          });
        });
      }
      vm.petForBudgetLine = function (project, line) {
        return ((project && project.pets) || []).filter(function (pet) { return pet.petId === line.petId; })[0];
      };
      function projectPetById(project, petId) {
        var id = Number(petId);
        return ((project && project.pets) || []).filter(function (pet) { return Number(pet.petId) === id; })[0];
      }
      vm.canExpandProject = function (project) {
        return !!project && ((project.petsLoaded && project.pets && project.pets.length) || Number(project.petCount) > 0 || Number(project.spendRequestCount) > 0 || Number(project.budgetLineCount) > 0 || Number(project.invoiceCount) > 0);
      };
      vm.toggleProject = function (project) {
        if (project.expanded) { project.expanded = false; redraw(); return; }
        if (project.petsLoaded || vm.demo) { project.expanded = true; redraw(); return; }
        loadProjectPets(project, true);
      };
      function loadProjectPets(project, expandRegardless, keepExpandedState) {
        project.loading = true;
        return $http.get("api/portfolio/projects/" + project.projectId).then(function (response) {
          var data = response.data;
          if (data.project) angular.extend(project, data.project);
          project.pets = data.pets || [];
          project.pets.forEach(function (pet) {
            pet.spendItems = (data.spendItems || []).filter(function (item) { return item.petId === pet.petId; }).map(normalizeSpendItem);
            pet.budgetLines = (data.budgetLines || []).filter(function (line) { return line.petId === pet.petId; });
            pet.budgetLines.forEach(function (line) { line.invoices = (data.invoices || []).filter(function (invoice) { return invoice.budgetLineId === line.budgetLineId; }); });
          });
          project.petsLoaded = true;
          project.loading = false;
          project.expanded = keepExpandedState ? !!project.expanded : expandRegardless || project.pets.length > 0;
          prepareProjects();
          vm.updateView(true);
          redraw();
        }, function () { project.loading = false; noticeError("Unable to load project details."); });
      }
      vm.openProject = function (project) {
        vm.modal = {
          type: "project",
          kicker: "PROJECT REGISTRATION",
          title: project ? "Edit project" : "Register a new project",
          submit: project ? "Save changes" : "Register project",
        };
        vm.form = angular.copy(
          project || {
            isJira: true,
            projectType: "Project",
            projectSize: "Medium",
            budgetType: "CAPEX",
            requiresPet: true,
          },
        );
        vm.form.isJira = project ? !!project.jiraKey : true;
        redraw();
      };
      vm.pickJira = function () {
        var jira = vm.jira.filter(function (j) {
          return j.jiraKey === vm.form.jiraKey;
        })[0];
        if (!jira) return;
        vm.form.projectName = jira.summary;
        vm.form.projectType = jira.projectType;
        vm.form.accountableExecLead = jira.accountableExecLead;
        vm.form.accountableExec = jira.accountableExec;
        vm.form.smeLead = jira.smeLead;
        vm.form.projectSize = jira.size || jira.projectSize || vm.form.projectSize;
        vm.form.projectManager = jira.assignedProjectManager;
      };
      vm.openJira = function (project) {
        var jira =
          vm.jira.filter(function (j) {
            return j.jiraKey === project.jiraKey;
          })[0] || project;
        vm.form = angular.extend({}, project, jira, {
          projectName: jira.summary || project.projectName,
        });
        vm.modal = {
          type: "jira",
          kicker: "SYNCHRONIZED JIRA DETAIL",
          title: project.jiraKey || project.projectCode,
        };
        redraw();
      };
      vm.openBudgetUsageProject = function (row) {
        var project = (vm.projects || []).filter(function (item) { return item.projectId === row.projectId || item.projectCode === row.projectCode || item.projectName === row.projectName; })[0];
        vm.openJira(project || row);
      };
      vm.openPet = function (project, pet) {
        if (!vm.demo && project) {
          return refreshProjectPets(project.projectId, false, true).then(function () {
            var refreshedPet = pet && projectPetById(project, pet.petId || pet.PetId);
            openPetModal(project, refreshedPet || pet);
          });
        }
        openPetModal(project, pet);
      };
      function openPetModal(project, pet) {
        vm.selectedProject = project;
        vm.selectedPet = pet;
        vm.uploadFile = null;
        vm.petLineUploadFile = null;
        vm.uploadPreview = [];
        vm.form = angular.copy(pet || {
            projectId: project.projectId,
          code: generatedPetReference(),
            currency: "AED",
            requestedAmount: 0,
            reviewRequired: !project.skipReview,
          });
        if (pet) {
          vm.form.petId = vm.form.petId || pet.petId || pet.PetId;
          vm.form.projectId = vm.form.projectId || project.projectId;
          vm.form.code = vm.form.code || pet.code || pet.Code;
          vm.form.currency = vm.form.currency || pet.currency || pet.Currency || "AED";
          vm.form.requestedAmount = parseNumericInput(vm.form.requestedAmount || pet.requestedAmount || pet.RequestedAmount);
          vm.form.status = vm.form.status || pet.status || pet.Status;
          if (vm.form.status === "Sent Back" && angular.isUndefined(vm.form.reviewRequired)) vm.form.reviewRequired = angular.isDefined(vm.form.ReviewRequired) ? !!vm.form.ReviewRequired : !project.skipReview;
          if (vm.form.status === "Sent Back") vm.form.comments = "";
          if (sameStatus(vm.form.status, "Approved")) vm.form.vendorName = existingPetVendor(pet);
        }
        vm.uploadPreview = ((pet && pet.spendItems) || []).map(function (item) { return preparePetUploadRow(angular.extend({ petReference: vm.form.code, projectId: vm.projectDisplayId(project), finalAed: spendItemFinalAed(item) }, item)); });
        vm.recalculateUploadPreview();
        vm.modal = {
          type: "pet",
          kicker: "PET REQUEST",
          title: pet ? "Edit " + vm.form.code : "Create PET for " + vm.projectDisplayId(project),
          submit: pet && sameStatus(vm.form.status, "Approved") ? "Save vendor name" : pet && vm.form.status === "Sent Back" ? "Resubmit for approval" : pet ? "Save PET" : "Submit for review",
        };
        redraw();
      }
      vm.petVendorOnly = function () { return vm.selectedPet && sameStatus(vm.form && vm.form.status || vm.selectedPet.status, "Approved"); };
      vm.openSpend = function (pet) {
        vm.selectedPet = pet;
        vm.selectedProject = vm.projects.filter(function (project) { return project.pets.indexOf(pet) >= 0; })[0];
        vm.selectedPet.spendItems = vm.selectedPet.spendItems || [];
        vm.spendEditable = vm.can("request") && (pet.status === "Pending Review" || pet.status === "Sent Back" || (pet.status === "Pending Approval" && vm.selectedProject && vm.selectedProject.skipReview));
        vm.spendFormVisible = false;
        vm.form = { petId: pet.petId, serialNo: "", lineDate: null, lineId: "", department: "", head: petProjectExpenseHead(vm.selectedProject), units: 1, currency: "AED", foreignAmount: 0, exchangeRate: 1, aedAmount: 0, contingencyPercent: 0 };
        vm.modal = { type: "spend", kicker: "PET COST DETAIL", title: "PET line items · " + pet.code, submit: "Save PET line item" };
        redraw();
      };
      vm.addSpend = function () {
        vm.form = { petId: vm.selectedPet.petId, serialNo: "", lineDate: null, lineId: "", department: "", head: petProjectExpenseHead(vm.selectedProject), units: 1, currency: "AED", foreignAmount: 0, exchangeRate: 1, aedAmount: 0, contingencyPercent: 0 };
        vm.spendFormVisible = true;
        redraw();
      };
      vm.editSpend = function (item) {
        vm.form = angular.copy(item);
        if (vm.form.lineDate && !angular.isDate(vm.form.lineDate)) vm.form.lineDate = new Date(vm.form.lineDate);
        vm.form.head = petProjectExpenseHead(vm.selectedProject) || vm.form.head;
        vm.form.exchangeRate = parseNumericInput(vm.form.exchangeRate) || (parseNumericInput(vm.form.foreignAmount) ? parseNumericInput(vm.form.aedAmount) / parseNumericInput(vm.form.foreignAmount) : 1);
        vm.spendFormVisible = true;
        redraw();
      };
      vm.openDecision = function (pet, stage) {
        vm.bulkDecisionItems = [];
        vm.decisionPetRows = [];
        vm.decisionSelection = {};
        var project = vm.projects.filter(function (p) {
          return p.pets.indexOf(pet) >= 0;
        })[0];
        if (project && !vm.demo) {
          project.petsLoaded = false;
          loadProjectPets(project, false, true).then(function () {
            openDecisionModal(projectPetById(project, pet.petId) || pet, stage, project);
          });
          return;
        }
        openDecisionModal(pet, stage, project);
      };
      vm.openBulkDecision = function (stage) {
        var items = vm.selectedApprovalItems(stage);
        if (!items.length) { noticeError("Select at least one PET to " + (stage === "approve" ? "approve" : "review") + "."); return; }
        vm.bulkDecisionItems = items;
        vm.selectedProject = items[0].project;
        vm.selectedPet = items[0].pet;
        vm.form = {
          decision: "Approve",
          comments: "",
          budgetSourceId: vm.selectedProject && vm.selectedProject.budgetSourceId,
          requestedAmount: items.reduce(function (total, item) { return total + (Number(item.pet.requestedAmount) || 0); }, 0),
          code: items.length + " PETs selected",
        };
        vm.modal = {
          type: "decision",
          stage: stage,
          bulk: true,
          kicker: stage === "review" ? "REVIEWER DECISION" : "APPROVER DECISION",
          title: stage === "review" ? "Review selected PETs" : "Approve selected PETs",
          submit: "Record decisions",
        };
        redraw();
      };
      function openDecisionModal(pet, stage, project) {
        vm.bulkDecisionItems = [];
        vm.selectedProject = project;
        vm.selectedPet = pet;
        vm.selectedPet.spendItems = vm.selectedPet.spendItems || [];
        vm.form = angular.copy(pet);
        vm.form.decision = "Approve";
        vm.form.comments = "";
        vm.form.budgetSourceId = vm.selectedProject && vm.selectedProject.budgetSourceId;
        vm.modal = {
          type: "decision",
          stage: stage,
          bulk: true,
          kicker:
            stage === "review" ? "REVIEWER DECISION" : "APPROVER DECISION",
          title: stage === "review" ? "Review PET" : "Approve PET",
          submit: "Record decision",
        };
        buildDecisionPetRows(project, pet, stage);
        redraw();
      }
      vm.openHistory = function (project, pet) {
        vm.selectedProject = project;
        vm.selectedPet = pet;
        vm.history = [];
        vm.modal = { type: "history", kicker: "WORKFLOW HISTORY", title: "History · " + pet.code };
        redraw();
        if (vm.demo) return;
        $http.get("api/portfolio/pets/" + pet.petId + "/history").then(function (response) {
          vm.history = response.data || [];
          redraw();
        }, function () { noticeError("Unable to load workflow history."); });
      };
      vm.openBudgetLine = function (pet, line) {
        vm.selectedPet = pet;
        vm.selectedProject = vm.projects.filter(function (p) { return p.pets.indexOf(pet) >= 0; })[0];
        vm.form = angular.copy(
          line || {
            petId: pet.petId,
            currency: "AED",
            camStatus: "Raised to Vendor",
          },
        );
        vm.form.petId = vm.form.petId || pet.petId;
        vm.selectedPet = projectPetById(vm.selectedProject, vm.form.petId) || pet;
        vm.form.petReference = vm.form.petReference || vm.selectedPet.code;
        var petVendors = vm.petVendorOptions(vm.selectedPet);
        vm.budgetLineVendorOptions = petVendors;
        if (!line) vm.form.vendor = petVendors[0] || "";
        applyBudgetLinePetValues();
        if (vm.form.camCreatedDate) vm.form.camCreatedDate = new Date(vm.form.camCreatedDate);
        if (vm.form.camApprovedDate) vm.form.camApprovedDate = new Date(vm.form.camApprovedDate);
        if (vm.form.lpoIssueDate) vm.form.lpoIssueDate = new Date(vm.form.lpoIssueDate);
        vm.modal = {
          type: "budgetLine",
          kicker: "APPROVED PET",
          title: line ? "Edit budget line" : "Add budget line",
          submit: "Save budget line",
        };
        redraw();
      };
      vm.onBudgetLinePetChange = function (skipAutoFill) {
        var pet = projectPetById(vm.selectedProject, vm.form && vm.form.petId);
        if (!pet) { vm.selectedPet = null; vm.budgetLineVendorOptions = []; vm.budgetLineSpendDetails = []; if (vm.form) vm.form.petReference = null; return; }
        var petChanged = !vm.selectedPet || Number(vm.selectedPet.petId) !== Number(pet.petId);
        vm.selectedPet = pet;
        vm.form.petReference = pet.code;
        var petVendors = vm.petVendorOptions(pet);
        vm.budgetLineVendorOptions = petVendors;
        if (vm.form.budgetLineId) { refreshBudgetLineSpendDetails(); return; }
        var selectedVendors = splitVendorNames(vm.form.vendor);
        var hasInvalidVendor = selectedVendors.some(function (vendor) { return !petVendors.some(function (allowed) { return allowed.toLowerCase() === vendor.toLowerCase(); }); });
        if (petVendors.length && (!selectedVendors.length || hasInvalidVendor)) vm.form.vendor = petVendors[0];
        if (!petVendors.length && petChanged) vm.form.vendor = "";
        if (skipAutoFill) { refreshBudgetLineSpendDetails(); return; }
        applyBudgetLinePetValues();
      };
      vm.openProjectBudgetLine = function (project) {
        var pet = vm.petForNewBudgetLine(project);
        if (!pet && project && !project.petsLoaded && Number(project.approvedPetCount) > 0) {
          loadProjectPets(project, true).then(function () {
            var loadedPet = vm.petForNewBudgetLine(project);
            if (loadedPet) vm.openBudgetLine(loadedPet);
          });
          return;
        }
        if (!pet) return;
        vm.openBudgetLine(pet);
      };
      vm.openInvoice = function (line, invoice) {
        vm.selectedLine = line;
        vm.selectedProject = vm.projects.filter(function (p) {
          return p.pets.some(function (pet) { return pet.budgetLines && pet.budgetLines.indexOf(line) >= 0; });
        })[0];
        vm.form = angular.copy(
          invoice || {
            budgetLineId: line.budgetLineId,
            vendorName: line.vendor,
            glNumber: line.glNumber,
            invoiceStatus: "Raised",
          },
        );
        if (vm.form.paymentDate)
          vm.form.paymentDate = new Date(vm.form.paymentDate);
        vm.modal = {
          type: "invoice",
          kicker: "INVOICE REGISTER",
          title: invoice ? "Update invoice" : "Add invoice",
          submit: "Save invoice",
        };
        redraw();
      };
      vm.openInvoiceView = function (line) {
        vm.selectedLine = line;
        vm.selectedProject = vm.projects.filter(function (p) {
          return p.pets.some(function (pet) { return pet.budgetLines && pet.budgetLines.indexOf(line) >= 0; });
        })[0];
        function showInvoices(sourceLine) {
          vm.selectedLine = sourceLine || line;
          vm.invoices = (vm.selectedLine && vm.selectedLine.invoices) || [];
          vm.modal = { type: "invoiceView", kicker: "INVOICE VIEW", title: "Invoices · " + (vm.selectedLine.petReference || vm.selectedLine.petCode || vm.selectedLine.camId || "Budget Line") };
          redraw();
        }
        if (vm.selectedProject && !vm.demo) {
          refreshProjectPets(vm.selectedProject.projectId, true).then(function () {
            var refreshedLine = null;
            (vm.selectedProject.budgetLines || []).forEach(function (candidate) {
              if (Number(candidate.budgetLineId) === Number(line.budgetLineId)) refreshedLine = candidate;
            });
            showInvoices(refreshedLine);
          });
          return;
        }
        showInvoices(line);
      };
      vm.openBudget = function (budget) {
        vm.selectedBudget = budget;
        vm.form = angular.copy(budget);
        vm.modal = {
          type: "budget",
          kicker: "MASTER CONTROL",
          title: "Edit " + budget.externalId,
          submit: "Update budget",
        };
        redraw();
      };
      vm.openUpload = function (kind, item) {
        var templates = {
          pet: "templates/pet-upload-template.csv",
          budget: "templates/budget-upload-template.csv",
          invoice: "templates/invoice-upload-template.csv",
        };
        vm.modal = {
          type: "upload",
          kind: kind,
          kicker: "BULK IMPORT",
          title:
            kind === "attachment"
              ? "Attach supporting files"
              : "Upload " + kind + " records",
          submit: kind === "pet" ? "Save PET rows" : "Upload files",
          template: templates[kind],
          help:
            kind === "attachment"
              ? "PDF, spreadsheet and image files up to 50 MB."
              : kind === "pet"
                ? "Upload the Excel or CSV, review the rows below, edit any fields, or add PET rows manually before saving."
                : "Use the supplied columns in CSV, XLSX, or XLSM format. Invalid rows are rejected with a row-level reason.",
        };
        vm.uploadFile = null;
        vm.uploadPreview = [];
        vm.form = { item: item };
        if (kind === "pet") ensurePetReferenceNo();
        redraw();
      };
      vm.download = function (kind) {
        window.location.href = "templates/" + kind + "-upload-template.csv";
      };
      vm.close = function () {
        vm.modal = null;
        vm.form = {};
        vm.uploadFile = null;
        vm.uploadPreview = [];
        vm.bulkDecisionItems = [];
        vm.decisionPetRows = [];
        vm.decisionSelection = {};
        vm.budgetLineVendorOptions = [];
        vm.budgetLineSpendDetails = [];
        redraw();
      };
      function runBulkImport(kind, parentId, onDone) {
        if (!vm.uploadFile) { noticeError("Choose a CSV or Excel file first."); return; }
        var formData = new FormData();
        formData.append("file", vm.uploadFile);
        $http.post("api/portfolio/bulk/" + kind + "/" + parentId, formData, { transformRequest: angular.identity, headers: { "Content-Type": undefined } }).then(function (response) {
          notice((response.data.imported || 0) + " row(s) imported.");
          vm.uploadFile = null;
          vm.close();
          loadDashboard().then(function () { if (onDone) onDone(); });
        }, function (response) {
          noticeError(responseMessage(response, "Import failed."));
        });
      }
      function uploadAttachment(entityType, entityId, file) {
        if (!file || !entityId || vm.demo) return $q.when();
        var formData = new FormData();
        formData.append("file", file);
        return $http.post("api/portfolio/attachments/" + entityType + "/" + entityId, formData, { transformRequest: angular.identity, headers: { "Content-Type": undefined } });
      }
      function savePreviewItems(petId) {
        if ((vm.uploadPreview || []).length && !petId) return $q.reject({ data: { message: "PET was saved, but the PET id was not returned." } });
        var chain = $q.when();
        (vm.uploadPreview || []).forEach(function (row) {
          chain = chain.then(function () {
            var payload = angular.extend({}, row, { petId: petId });
            applyPetProjectDefaults(payload);
            payload.units = parseNumericInput(payload.units);
            payload.unitPrice = parseNumericInput(payload.unitPrice);
            payload.foreignAmount = parseNumericInput(payload.foreignAmount) || payload.units * payload.unitPrice;
            payload.exchangeRate = parseNumericInput(payload.exchangeRate) || 1;
            payload.aedAmount = parseNumericInput(payload.aedAmount) || payload.foreignAmount;
            payload.contingencyPercent = parseNumericInput(payload.contingencyPercent);
            payload.yearlyRecurrence = blankNumericInput(payload.yearlyRecurrence) ? null : parseNumericInput(payload.yearlyRecurrence);
            return $http.post("api/portfolio/spend-items", payload);
          });
        });
        return chain;
      }
      function responseMessage(response, fallback) {
        if (!response || response.data == null) return fallback;
        if (response.status === 401) { vm.signOut(); return "Your session has expired or is not authenticated. Please sign in again before saving."; }
        if (response.status === 403) return "Your account does not have permission to save this item. Ask an admin to assign the required role.";
        if (typeof response.data === "string") return /<html|<!doctype/i.test(response.data) ? fallback : response.data;
        return response.data.message || response.data.Message || fallback;
      }
      function authResponseMessage(response, fallback) {
        if (!response || response.data == null) return fallback;
        if (typeof response.data === "string") return /<html|<!doctype/i.test(response.data) ? fallback : response.data;
        if (response.status === 401) return "Invalid email ID, password, or security answer.";
        return response.data.message || response.data.Message || fallback;
      }
      vm.saveModal = function () {
        var type = vm.modal.type;
        if (type === "project" && !vm.demo) {
          // Registration is one-time (no projectId -> insert); every save after that is an
          // update against the same projectId, so a project can be edited any number of times.
          var payload = {
            projectId: vm.form.projectId || null,
            isJira: !!vm.form.isJira,
            jiraKey: vm.form.isJira ? vm.form.jiraKey : null,
            projectName: vm.form.projectName,
            projectType: vm.form.projectType,
            accountableExecLead: vm.form.accountableExecLead,
            accountableExec: vm.form.accountableExec,
            smeLead: vm.form.smeLead,
            projectSize: vm.form.projectSize,
            projectManager: vm.form.projectManager,
            budgetType: vm.form.budgetType,
            budgetSourceId: vm.form.budgetSourceId,
          };
          $http.post("api/portfolio/projects", payload).then(function () {
            notice(payload.projectId ? "Project updated" : "Project registered");
            vm.close();
            loadDashboard();
          }, function (response) {
            noticeError(responseMessage(response, "Unable to save the project."));
          });
          return;
        }
        if (type === "project") {
          var existing =
            vm.form.projectId &&
            vm.projects.filter(function (p) {
              return p.projectId === vm.form.projectId;
            })[0];
          var budget = vm.budgets.filter(function (b) {
            return String(b.budgetSourceId) === String(vm.form.budgetSourceId);
          })[0];
          if (existing) angular.extend(existing, vm.form);
          else {
            vm.form.projectId = vm.projects.length + 1;
            vm.form.projectCode =
              "PRJ-" + ("000000" + vm.form.projectId).slice(-6);
            vm.form.jiraKey = vm.form.isJira ? vm.form.jiraKey : null;
            vm.form.requestorEmail = vm.session.email;
            vm.form.requestorName = vm.session.displayName;
            vm.form.status = "Active";
            vm.form.createdUtc = new Date();
            vm.form.pets = [];
            vm.form.petsLoaded = true;
            vm.form.budgetSource = budget ? budget.externalId : "Not required";
            vm.form.availableBudget = budget ? budget.availableBudget : 0;
            vm.projects.unshift(vm.form);
            vm.metrics.projectsRegistered++;
          }
          prepareProjects();
          vm.updateView();
          notice("Project saved");
        }
        if (type === "pet" && !vm.demo) {
          if (vm.petVendorOnly()) {
            var vendorPayload = {
              petId: vm.form.petId,
              projectId: vm.form.projectId || vm.selectedProject.projectId,
              code: vm.form.code,
                requestedAmount: parseNumericInput(vm.form.requestedAmount),
              currency: vm.form.currency || "AED",
              vendorName: vm.form.vendorName,
              vendorNameOnly: true,
            };
            $http.post("api/portfolio/pets", vendorPayload).then(function () {
              vm.selectedPet.vendorName = vm.form.vendorName;
              notice("PET vendor name updated");
              vm.close();
            }, function (response) {
              noticeError(responseMessage(response, "Unable to update the PET vendor name."));
            });
            return;
          }
          if (vm.form.status === "Sent Back" && !String(vm.form.comments || "").trim()) { noticeError("Requester comments / amendment notes are required before resubmitting."); return; }
          if (!vm.selectedPet && (vm.uploadPreview || []).length) {
            var bulkPetProjectId = vm.selectedProject.projectId;
            savePetUploadRows(bulkPetProjectId, function () { refreshProjectPets(bulkPetProjectId, true); }, vm.form.reviewRequired);
            return;
          }
          if (!vm.selectedPet && !(vm.uploadPreview || []).length) { noticeError("Upload Excel rows or add a PET row before saving."); return; }
          if ((vm.uploadPreview || []).length && !validatePetUploadRows()) return;
          if ((vm.uploadPreview || []).length) vm.form.requestedAmount = vm.petUploadTotal;
          if (!validatePetRequestAmount(vm.selectedProject, vm.selectedPet, vm.form.requestedAmount)) return;
          var supportingDocument = vm.uploadFile;
          var petPayload = {
            petId: vm.form.petId || null,
            projectId: vm.selectedProject.projectId,
            code: vm.form.code,
            requestedAmount: (vm.uploadPreview || []).length ? vm.petUploadTotal : parseNumericInput(vm.form.requestedAmount),
            currency: vm.form.currency,
            vendorName: vm.form.vendorName,
            comments: vm.form.comments,
            reviewRequired: vm.form.reviewRequired,
          };
          if ((vm.uploadPreview || []).length) petPayload.spendItems = petLinePayloads(vm.form.petId || 0);
          $http.post("api/portfolio/pets", petPayload).then(function (response) {
            var savedPetId = petPayload.petId || response.data && (response.data.petId || response.data.PetId);
            uploadAttachment("pet", savedPetId, supportingDocument).then(function () {
              notice(vm.form.status === "Sent Back" ? "PET resubmitted for approval" : petPayload.petId ? "PET updated" : "PET submitted for review");
              vm.close();
              refreshProjectPets(petPayload.projectId, true);
              loadDashboard();
            }, function (attachmentResponse) {
              noticeError(responseMessage(attachmentResponse, "PET was saved, but the supporting document upload failed."));
            });
          }, function (response) {
            noticeError(responseMessage(response, "Unable to save the PET."));
          });
          return;
        }
        if (type === "pet") {
          if (vm.petVendorOnly()) {
            vm.selectedPet.vendorName = vm.form.vendorName;
            notice("PET vendor name updated");
            vm.close();
            return;
          }
          if (vm.form.status === "Sent Back" && !String(vm.form.comments || "").trim()) { noticeError("Requester comments / amendment notes are required before resubmitting."); return; }
          if ((vm.uploadPreview || []).length && !validatePetUploadRows()) return;
          if ((vm.uploadPreview || []).length) vm.form.requestedAmount = vm.petUploadTotal;
          else vm.form.requestedAmount = parseNumericInput(vm.form.requestedAmount);
          if (!validatePetRequestAmount(vm.selectedProject, vm.selectedPet, vm.form.requestedAmount)) return;
          var wasSentBack = vm.selectedPet && vm.selectedPet.status === "Sent Back";
          var demoPetId = vm.form.petId || Date.now();
          vm.form.spendItems = (vm.uploadPreview || []).length ? petLinePayloads(demoPetId) : (vm.form.spendItems || []);
          if (vm.selectedPet) angular.extend(vm.selectedPet, vm.form);
          else {
            vm.form.petId = demoPetId;
            vm.form.status = vm.form.reviewRequired ? "Pending Review" : "Pending Approval";
            vm.form.createdUtc = new Date();
            vm.form.spendItems = vm.form.spendItems || [];
            vm.form.budgetLines = [];
            vm.selectedProject.pets.push(vm.form);
            vm.metrics.petsOnTrack++;
          }
          if (wasSentBack) vm.selectedPet.status = vm.form.reviewRequired ? "Pending Review" : "Pending Approval";
          vm.selectedProject.status = wasSentBack ? vm.selectedPet.status : vm.form.reviewRequired ? "Pending Review" : "Pending Approval";
          prepareProjects();
          vm.updateView();
          notice(wasSentBack ? "PET resubmitted for approval" : vm.selectedPet ? "PET updated" : vm.form.reviewRequired ? "PET submitted to the Accountable Executive Lead" : "PET sent directly to the Accountable Executive");
        }
        if (type === "spend" && !vm.demo) {
          if (!validateSpendFormAmounts(vm.form)) return;
          vm.recalculateSpendForm();
          var spendPayload = angular.extend({}, vm.form, { petId: vm.selectedPet.petId });
          spendPayload.head = petProjectExpenseHead(vm.selectedProject) || spendPayload.head;
          spendPayload.units = parseNumericInput(spendPayload.units);
          spendPayload.unitPrice = parseNumericInput(spendPayload.unitPrice);
          spendPayload.foreignAmount = spendForeignAmount(spendPayload);
          spendPayload.exchangeRate = String(spendPayload.currency || "AED").toUpperCase() === "AED" ? 1 : parseNumericInput(spendPayload.exchangeRate) || 1;
          spendPayload.aedAmount = spendAedAmount(spendPayload);
          spendPayload.contingencyPercent = parseNumericInput(spendPayload.contingencyPercent);
          if (!validatePetRequestAmount(vm.selectedProject, vm.selectedPet, petFinalAedWithSpend(vm.selectedPet, spendPayload))) return;
          var isNewSpend = !spendPayload.spendItemId;
          $http.post("api/portfolio/spend-items", spendPayload).then(function (response) {
            var saved = response.data || {};
            spendPayload.spendItemId = saved.spendItemId || spendPayload.spendItemId;
            spendPayload.foreignAmount = spendPayload.foreignAmount || spendPayload.units * spendPayload.unitPrice;
            spendPayload.aedAmount = spendPayload.aedAmount || spendPayload.foreignAmount;
            if (isNewSpend) vm.selectedPet.spendItems.push(spendPayload);
            else angular.extend(vm.selectedPet.spendItems.filter(function (item) { return item.spendItemId === spendPayload.spendItemId; })[0] || {}, spendPayload);
            if (saved.finalRequestAedAmount != null) vm.selectedPet.requestedAmount = saved.finalRequestAedAmount;
            notice("PET line item saved");
            vm.spendFormVisible = false;
            prepareProjects();
            vm.updateView(true);
            redraw();
          }, function (response) {
            noticeError(responseMessage(response, "Unable to save the PET line item."));
          });
          return;
        }
        if (type === "spend") {
          if (!validateSpendFormAmounts(vm.form)) return;
          vm.recalculateSpendForm();
          var demoSpendPayload = angular.extend({}, vm.form);
          demoSpendPayload.head = petProjectExpenseHead(vm.selectedProject) || demoSpendPayload.head;
          demoSpendPayload.units = parseNumericInput(demoSpendPayload.units);
          demoSpendPayload.unitPrice = parseNumericInput(demoSpendPayload.unitPrice);
          demoSpendPayload.foreignAmount = spendForeignAmount(demoSpendPayload);
          demoSpendPayload.exchangeRate = String(demoSpendPayload.currency || "AED").toUpperCase() === "AED" ? 1 : parseNumericInput(demoSpendPayload.exchangeRate) || 1;
          demoSpendPayload.aedAmount = spendAedAmount(demoSpendPayload);
          demoSpendPayload.contingencyPercent = parseNumericInput(demoSpendPayload.contingencyPercent);
          var oldSpend = demoSpendPayload.spendItemId && vm.selectedPet.spendItems.filter(function (item) { return item.spendItemId === demoSpendPayload.spendItemId; })[0];
          if (!validatePetRequestAmount(vm.selectedProject, vm.selectedPet, petFinalAedWithSpend(vm.selectedPet, demoSpendPayload))) return;
          if (oldSpend) angular.extend(oldSpend, demoSpendPayload);
          else { demoSpendPayload.spendItemId = Date.now(); vm.selectedPet.spendItems.push(demoSpendPayload); }
          vm.selectedPet.requestedAmount = vm.petFinalAed(vm.selectedPet);
          prepareProjects();
          vm.updateView();
          notice("PET line item saved");
        }
        if (type === "decision" && !vm.demo) {
          var decisionRoute = vm.modal.stage === "review" ? "review" : "approve";
          if (!vm.form.decision) { noticeError("Select a decision before recording this request."); return; }
          if ((vm.form.decision === "SendBack" || vm.form.decision === "RejectCancel") && !String(vm.form.comments || "").trim()) { noticeError("Comments / reason is required for this decision."); return; }
          if (vm.decisionCapexEditable() && !vm.form.budgetSourceId) { noticeError("Select a CapEx source before approval."); return; }
          var decisionPayload = { comments: vm.form.comments, decision: vm.form.decision, approve: vm.form.decision === "Approve" };
          if (vm.decisionCapexEditable()) decisionPayload.budgetSourceId = vm.form.budgetSourceId;
          var decisionItems = vm.modal.bulk ? vm.bulkDecisionItems.slice(0) : [{ project: vm.selectedProject, pet: vm.form }];
          if (!decisionItems.length) { noticeError("Select at least one PET before recording this decision."); return; }
          var projectIds = decisionItems.map(function (item) { return item.project && item.project.projectId; });
          $q.all(decisionItems.map(function (item) {
            return $http.post("api/portfolio/pets/" + item.pet.petId + "/" + decisionRoute, angular.copy(decisionPayload));
          })).then(function () {
            notice(vm.modal.bulk ? decisionItems.length + " PET decision(s) recorded" : "Decision recorded");
            vm.clearApprovalSelection();
            vm.close();
            refreshProjectsFromDatabase(projectIds);
          }, function (response) {
            noticeError(responseMessage(response, "Unable to record this decision."));
            refreshProjectsFromDatabase(projectIds);
          });
          return;
        }
        if (type === "decision") {
          if (!vm.form.decision) { noticeError("Select a decision before recording this request."); return; }
          if ((vm.form.decision === "SendBack" || vm.form.decision === "RejectCancel") && !String(vm.form.comments || "").trim()) { noticeError("Comments / reason is required for this decision."); return; }
          if (vm.decisionCapexEditable() && !vm.form.budgetSourceId) { noticeError("Select a CapEx source before approval."); return; }
          var demoDecisionItems = vm.modal.bulk ? vm.bulkDecisionItems.slice(0) : [{ project: vm.selectedProject, pet: vm.form }];
          if (!demoDecisionItems.length) { noticeError("Select at least one PET before recording this decision."); return; }
          demoDecisionItems.forEach(function (item) {
            var project = item.project || vm.selectedProject;
            var target = project.pets.filter(function (p) { return p.petId === item.pet.petId; })[0];
            if (!target) return;
            target.status = vm.form.decision === "SendBack" ? "Sent Back" : vm.form.decision === "RejectCancel" ? "Rejected" : vm.modal.stage === "review" ? "Pending Approval" : "Approved";
            project.status = target.status;
            if (target.status === "Pending Approval" && vm.form.budgetSourceId) {
              var reviewBudget = vm.selectedBudgetSource();
              project.budgetSourceId = vm.form.budgetSourceId;
              project.budgetType = "CAPEX";
              if (reviewBudget) project.budgetSource = reviewBudget.externalId;
            }
            if (target.status === "Approved") {
              if (vm.form.budgetSourceId) {
                var selectedBudget = vm.selectedBudgetSource();
                project.budgetSourceId = vm.form.budgetSourceId;
                project.budgetType = "CAPEX";
                if (selectedBudget) project.budgetSource = selectedBudget.externalId;
              }
              vm.metrics.petsApproved++;
              vm.metrics.petsOnTrack--;
              project.availableBudget -= target.requestedAmount;
            } else if (target.status === "Rejected") {
              vm.metrics.petsRejected++;
              vm.metrics.petsOnTrack--;
            }
            if (vm.modal.stage === "review") { target.reviewerEmail = vm.session.email; target.reviewedUtc = new Date(); }
            if (vm.modal.stage === "approve") target.approverEmail = vm.session.email;
          });
          prepareProjects();
          vm.updateView();
          notice(demoDecisionItems.length + " PET decision(s) recorded");
        }
        if (type === "budgetLine" && !vm.demo) {
          vm.onBudgetLinePetChange(true);
          if (!vm.selectedPet) { noticeError("Select a PET reference before saving the budget line."); return; }
          if (!validateBudgetLineVendorSelection()) return;
          if (!validateBudgetLineAmount()) return;
          var budgetLinePayload = angular.extend({}, vm.form, { petId: vm.selectedPet.petId, petReference: vm.form.petReference || vm.selectedPet.code });
          $http.post("api/portfolio/budget-lines", budgetLinePayload).then(function () {
            notice("Budget line saved");
            vm.close();
            if (vm.selectedProject) refreshProjectPets(vm.selectedProject.projectId, true);
            loadDashboard();
          }, function (response) {
            noticeError(responseMessage(response, "Unable to save the budget line."));
          });
          return;
        }
        if (type === "budgetLine") {
          vm.onBudgetLinePetChange(true);
          if (!vm.selectedPet) { noticeError("Select a PET reference before saving the budget line."); return; }
          if (!validateBudgetLineVendorSelection()) return;
          if (!validateBudgetLineAmount()) return;
          vm.form.petReference = vm.form.petReference || vm.selectedPet.code;
          var old =
            vm.form.budgetLineId &&
            vm.selectedPet.budgetLines.filter(function (x) {
              return x.budgetLineId === vm.form.budgetLineId;
            })[0];
          if (old) angular.extend(old, vm.form);
          else {
            vm.form.budgetLineId = Date.now();
            vm.form.invoices = [];
            vm.selectedPet.budgetLines.push(vm.form);
          }
          prepareProjects();
          vm.updateView();
          notice("Budget line saved");
        }
        if (type === "invoice" && !vm.demo) {
          if (!validateNumericInput(vm.form && vm.form.invoiceAmount, "Invoice amount", false)) return;
          var invoicePayload = angular.extend({}, vm.form, { budgetLineId: vm.selectedLine.budgetLineId });
          invoicePayload.invoiceAmount = parseNumericInput(invoicePayload.invoiceAmount);
          $http.post("api/portfolio/invoices", invoicePayload).then(function () {
            notice("Invoice saved");
            vm.close();
            if (vm.selectedProject) refreshProjectPets(vm.selectedProject.projectId, true);
            loadDashboard();
          }, function (response) {
            noticeError(responseMessage(response, "Unable to save the invoice."));
          });
          return;
        }
        if (type === "invoice") {
          if (!validateNumericInput(vm.form && vm.form.invoiceAmount, "Invoice amount", false)) return;
          vm.form.invoiceAmount = parseNumericInput(vm.form.invoiceAmount);
          var oldInvoice =
            vm.form.invoiceId &&
            vm.selectedLine.invoices.filter(function (x) {
              return x.invoiceId === vm.form.invoiceId;
            })[0];
          if (oldInvoice) angular.extend(oldInvoice, vm.form);
          else {
            vm.form.invoiceId = Date.now();
            vm.selectedLine.invoices.push(vm.form);
            vm.metrics.invoicesRaised++;
            vm.metrics.invoicesOutstanding++;
          }
          prepareProjects();
          vm.updateView();
          notice("Invoice saved");
        }
        if (type === "budget") {
          if (!validateBudgetSourceAmounts(vm.form)) return;
          vm.form.budget = parseNumericInput(vm.form.budget);
          vm.form.utilization = parseNumericInput(vm.form.utilization);
          vm.form.availableBudget = parseNumericInput(vm.form.availableBudget);
          angular.extend(vm.selectedBudget, vm.form);
          notice("Budget source updated");
        }
        if (type === "upload" && vm.modal.kind !== "attachment" && vm.modal.kind !== "sources" && !vm.demo) {
          var item = vm.form.item;
          var kind = vm.modal.kind;
          var parentId = kind === "pet" ? item.projectId : kind === "budget" ? item.petId : kind === "invoice" ? item.budgetLineId : null;
          if (!parentId) { noticeError("Unable to determine where to import these rows."); return; }
          if (kind === "pet") {
            savePetUploadRows(parentId, function () { refreshProjectPets(parentId, true); });
            return;
          }
          runBulkImport(kind, parentId, function () {
            if (vm.selectedProject) refreshProjectPets(vm.selectedProject.projectId, true);
          });
          return;
        }
        if (type === "upload") notice("File accepted for validation");
        vm.close();
        redraw();
      };
      var toastTimer;
      function notice(message) {
        if (toastTimer) $timeout.cancel(toastTimer);
        vm.toast = message;
        vm.toastIsError = false;
        toastTimer = $timeout(function () {
          vm.toast = "";
        }, 3000);
      }
      // Error toasts stay on screen (no auto-dismiss) until the user closes them or another
      // notice/noticeError replaces them, per the "don't hide errors" requirement.
      function noticeError(message) {
        if (toastTimer) $timeout.cancel(toastTimer);
        vm.toast = message;
        vm.toastIsError = true;
      }
      vm.dismissToast = function () {
        if (toastTimer) $timeout.cancel(toastTimer);
        vm.toast = "";
        vm.toastIsError = false;
      };
      var iconTimer;
      function redraw() {
        if (iconTimer) $timeout.cancel(iconTimer);
        iconTimer = $timeout(function () {
          if (window.lucide)
            window.lucide.createIcons({ attrs: { "stroke-width": 1.8 } });
        }, 0, false);
      }
      function loadDashboard() {
        return $http.get("api/portfolio/dashboard").then(function (response) {
          var data = response.data || {};
          vm.demo = false;
          vm.metrics = (data.metrics && data.metrics[0]) || vm.metrics;
          mergeProjects(data.projects || []);
          mergeApprovalPets(data.approvalPets || []);
          vm.budgets = data.budgets || [];
          vm.jira = data.jira || [];
          vm.budgetUsage = data.budgetUsage || [];
          prepareProjects();
          vm.updateView(true);
          redraw();
        }, function (response) {
          if (response && response.status === 401) vm.signOut();
          else noticeError("Unable to refresh transactions.");
          redraw();
          return $q.reject(response);
        });
      }
      // Preserves existing project objects (and their expanded/pets/petsLoaded state) instead of
      // replacing the whole array, so re-loading the dashboard after a save doesn't collapse rows
      // the user already had open.
      function mergeProjects(freshList) {
        var existingById = {};
        vm.projects.forEach(function (p) { existingById[p.projectId] = p; });
        vm.projects = freshList.map(function (fresh) {
          var existing = existingById[fresh.projectId];
          if (existing) { angular.extend(existing, fresh); return existing; }
          return fresh;
        });
      }
      function mergeApprovalPets(pets) {
        var projectsById = {};
        vm.projects.forEach(function (project) { projectsById[project.projectId] = project; });
        (pets || []).forEach(function (pet) {
          var project = projectsById[pet.projectId];
          if (!project) return;
          if (typeof project.petsLoaded === "undefined") project.petsLoaded = false;
          project.pets = project.pets || [];
          var existing = project.pets.filter(function (item) { return item.petId === pet.petId; })[0];
          if (existing) angular.extend(existing, pet);
          else project.pets.push(pet);
        });
      }
      function loadRoles() {
        if (!vm.hasRole("Admin") || vm.demo) return $q.when();
        return $http.get("api/portfolio/roles").then(function (response) {
          var data = response.data || {};
          vm.availableManagedRoles = data.roles || vm.availableManagedRoles;
          vm.roleUsers = normalizeRoleUsers(data.users || []);
          vm.updateRoleView();
          redraw();
        }, function () { noticeError("Unable to load role management."); });
      }
      function normalizeRoleUsers(users) {
        return users.map(function (user) {
          var roles = String(user.roles || "").split(",").filter(Boolean);
          user.roleMap = {};
          roles.forEach(function (role) { user.roleMap[role === "Master" ? "Admin" : role] = true; });
          user.elevatedRole = ["Reviewer", "Approver", "Admin"].filter(function (role) { return user.roleMap[role]; })[0] || "";
          user.roleList = roles.map(function (role) { return role === "Master" ? "Admin" : role; }).join(", ") || "Requestor";
          return user;
        });
      }
      function previewRoleUsers() {
        return normalizeRoleUsers([
          { userId: 1, displayName: "Preview User", email: "cards.requestor@dfm.ae", isActive: true, roles: "Requestor,Admin" },
          { userId: 2, displayName: "Amit Saxena", email: "amit.saxena@dfm.ae", isActive: true, roles: "Requestor,Reviewer" },
          { userId: 3, displayName: "Zahoor Ul Islam", email: "zahoor.ul.islam@dfm.ae", isActive: true, roles: "Requestor,Approver" },
        ]);
      }
      vm.saveUserRoles = function (user) {
        var selected = user.elevatedRole ? [user.elevatedRole] : [];
        if (vm.demo) { user.roleList = selected.length ? "Requestor, " + selected.join(", ") : "Requestor"; vm.updateRoleView(true); notice("Roles updated"); return; }
        $http.post("api/portfolio/roles", { userId: user.userId, roles: selected }).then(function () {
          user.roleList = selected.length ? "Requestor, " + selected.join(", ") : "Requestor";
          vm.updateRoleView(true);
          notice("Roles updated");
        }, function (response) { noticeError(responseMessage(response, "Unable to update roles.")); });
      };
      vm.refreshTransactions = function () {
        if (vm.refreshing) return;
        vm.refreshing = true;
        var loadedProjectIds = (vm.projects || []).filter(function (project) { return project.expanded || project.petsLoaded; }).map(function (project) { return project.projectId; });
        if (vm.demo) {
          prepareProjects();
          vm.updateView(true);
          vm.refreshing = false;
          notice("Transactions refreshed");
          redraw();
          return;
        }
        loadDashboard().then(function () {
          return $q.all(loadedProjectIds.map(function (projectId) { return refreshProjectPets(projectId, true, true); }));
        }).then(function () {
          return loadRoles();
        }).then(function () {
          notice("Transactions refreshed");
          vm.refreshing = false;
          redraw();
        }, function () {
          vm.refreshing = false;
          redraw();
        });
      };
      if (!restoreSession()) {
        prepareProjects();
        vm.updateView();
        redraw();
      }
    });
})();
