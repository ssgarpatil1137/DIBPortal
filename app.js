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
      vm.signOut = function () { vm.session = null; resetLoginAuth(); sessionStorage.removeItem("dfmToken"); delete $http.defaults.headers.common.Authorization; };
      vm.authenticate = function () {
        vm.auth.error = "";
        var route = vm.auth.mode === "login" ? "login" : vm.auth.mode === "setup" ? "first-time-setup" : vm.auth.mode === "reset" ? "reset/challenge" : "reset/complete";
        $http.post("api/auth/" + route, vm.auth).then(function (response) {
          if (vm.auth.mode === "login") {
            if (response.data.requiresPasswordSetup) { vm.auth.mode = "setup"; return; }
            saveRememberedLogin();
            sessionStorage.setItem("dfmToken", response.data.token); vm.session = response.data; vm.session.initials = (vm.session.displayName || vm.session.email).split(/\s+/).slice(0,2).map(function (part) { return part.charAt(0); }).join("").toUpperCase();
            $http.defaults.headers.common.Authorization = "Bearer " + response.data.token;
            updateNavigation();
            loadDashboard();
            loadRoles();
          } else if (vm.auth.mode === "reset") { vm.auth.resetToken = response.data.resetToken; vm.auth.mode = "complete"; }
          else { vm.auth = { mode: "login", email: vm.auth.email, rememberMe: vm.auth.rememberMe }; notice("Password saved. Sign in to continue."); }
          redraw();
        }, function (response) { vm.auth.error = response.data && response.data.message ? response.data.message : "Unable to complete this request."; });
      };
      function rememberedLoginEmail() {
        try { return localStorage.getItem("dfmRememberedEmail") || ""; }
        catch (ignore) { return ""; }
      }
      function saveRememberedLogin() {
        try {
          if (vm.auth.rememberMe && vm.auth.email) localStorage.setItem("dfmRememberedEmail", vm.auth.email);
          else localStorage.removeItem("dfmRememberedEmail");
        } catch (ignore) { }
      }
      function resetLoginAuth() {
        var email = rememberedLoginEmail();
        vm.auth = { mode: "login", email: email, rememberMe: !!email };
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
        return new Intl.NumberFormat("en-AE", {
          style: "currency",
          currency: "AED",
          maximumFractionDigits: 0,
        }).format(Number(value) || 0);
      };
      vm.projectDisplayId = function (project) { return project && project.jiraKey ? project.jiraKey : project.projectCode; };
      vm.selectedBudgetSource = function () {
        return (vm.budgets || []).filter(function (b) {
          return b.budgetSourceId === vm.form.budgetSourceId;
        })[0];
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
      // Login is by email, but JIRA only records the reviewer/approver's display name against
      // the project (AccountableExecLead/AccountableExec) - so match on Users.DisplayName, not email.
      vm.isReviewerFor = function (project) { return sameName(vm.session && vm.session.displayName, project.accountableExecLead); };
      vm.isApproverFor = function (project) { return sameName(vm.session && vm.session.displayName, project.accountableExec); };
      vm.isReviewerForPet = function (project, pet) { return sameEmail(vm.session && vm.session.email, pet && pet.reviewerEmail) || vm.isReviewerFor(project); };
      vm.isApproverForPet = function (project, pet) { return sameEmail(vm.session && vm.session.email, pet && pet.approverEmail) || vm.isApproverFor(project); };
      vm.setUploadFile = function (file) {
        vm.uploadFile = file;
        vm.uploadPreview = [];
        if (!file || vm.modal.type !== "pet") return;
        var reader = new FileReader();
        reader.onload = function (event) {
          $timeout(function () {
            var rows = parseCsv(event.target.result);
            if (rows.length < 2) return;
            var headers = rows[0].map(function (h) { return (h || "").replace(/[^a-z0-9]/gi, "").toLowerCase(); });
            var col = function (name) { return headers.indexOf(name); };
            var sum = 0;
            var preview = [];
            for (var r = 1; r < rows.length; r++) {
              var row = rows[r];
              if (!row.some(function (c) { return c && c.trim(); })) continue;
              var units = parseFloat(row[col("units")]) || 1;
              var unitPrice = parseFloat(row[col("unitprice")]) || 0;
              var foreign = parseFloat(row[col("fcyamount")]) || units * unitPrice;
              var aed = parseFloat(row[col("aedamount")]) || foreign;
              var contingency = parseFloat(row[col("contingency")]) || 0;
              var finalAedIdx = col("finalaed");
              var finalAed = finalAedIdx >= 0 && row[finalAedIdx] ? parseFloat(row[finalAedIdx]) : aed * (1 + contingency / 100);
              if (isNaN(finalAed)) finalAed = 0;
              sum += finalAed;
              preview.push({
                head: row[col("head")],
                topic: row[col("topic")],
                vendor: row[col("vendor")],
                costType: row[col("costtype")],
                unitType: row[col("unittype")],
                units: units,
                unitPrice: unitPrice,
                currency: row[col("currency")] || "AED",
                foreignAmount: foreign,
                aedAmount: aed,
                contingencyPercent: contingency,
                finalAed: finalAed,
                glNumber: row[col("glnumber")],
              });
              var refIdx = col("petreference");
              if (!vm.form.code && refIdx >= 0 && row[refIdx]) vm.form.code = row[refIdx];
            }
            vm.uploadPreview = preview;
            vm.form.requestedAmount = Math.round(sum * 100) / 100;
            redraw();
          });
        };
        reader.readAsText(file);
      };
      vm.recalculateUploadPreview = function () {
        var sum = 0;
        (vm.uploadPreview || []).forEach(function (row) {
          row.units = Number(row.units) || 0;
          row.unitPrice = Number(row.unitPrice) || 0;
          row.foreignAmount = Number(row.foreignAmount) || row.units * row.unitPrice;
          row.aedAmount = Number(row.aedAmount) || row.foreignAmount;
          row.contingencyPercent = Number(row.contingencyPercent) || 0;
          row.finalAed = row.aedAmount * (1 + row.contingencyPercent / 100);
          sum += row.finalAed;
        });
        vm.form.requestedAmount = Math.round(sum * 100) / 100;
      };
      function parseCsv(text) {
        var result = [], row = [], field = "", quoted = false;
        text = text || "";
        for (var i = 0; i < text.length; i++) {
          var ch = text[i];
          if (ch === '"') { if (quoted && text[i + 1] === '"') { field += '"'; i++; } else quoted = !quoted; }
          else if (ch === "," && !quoted) { row.push(field); field = ""; }
          else if ((ch === "\r" || ch === "\n") && !quoted) { if (ch === "\r" && text[i + 1] === "\n") i++; row.push(field); field = ""; result.push(row); row = []; }
          else field += ch;
        }
        if (field.length || row.length) { row.push(field); result.push(row); }
        return result;
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
      function refreshProjectPets(projectId, expandRegardless) {
        var project = vm.projects.filter(function (p) { return p.projectId === projectId; })[0];
        if (!project) return;
        project.petsLoaded = false;
        loadProjectPets(project, expandRegardless);
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
        if (!pet.spendItems || !pet.spendItems.length) return Number(pet.requestedAmount) || 0;
        return pet.spendItems.reduce(function (total, item) { return total + (Number(item.aedAmount) || 0) * (1 + (Number(item.contingencyPercent) || 0) / 100); }, 0);
      };
      function petBudgetLineTotal(pet, excludeBudgetLineId) {
        return ((pet && pet.budgetLines) || []).reduce(function (total, line) {
          if (excludeBudgetLineId && String(line.budgetLineId) === String(excludeBudgetLineId)) return total;
          return total + (Number(line.cost) || 0);
        }, 0);
      }
      vm.petBudgetLineAvailable = function (pet, excludeBudgetLineId) {
        return Math.max((Number(pet && pet.requestedAmount) || 0) - petBudgetLineTotal(pet, excludeBudgetLineId), 0);
      };
      function spendItemFinalAed(item) {
        var foreignAmount = Number(item.foreignAmount) || (Number(item.units) || 0) * (Number(item.unitPrice) || 0);
        var aedAmount = Number(item.aedAmount) || foreignAmount;
        return aedAmount * (1 + (Number(item.contingencyPercent) || 0) / 100);
      }
      function petFinalAedWithSpend(pet, item) {
        var spendItemId = item && item.spendItemId;
        var existing = ((pet && pet.spendItems) || []).reduce(function (total, current) {
          if (spendItemId && String(current.spendItemId) === String(spendItemId)) return total;
          return total + spendItemFinalAed(current);
        }, 0);
        return existing + spendItemFinalAed(item || {});
      }
      function projectBudgetAmount(project) {
        return Number(project && project.budget) || Number(project && project.availableBudget) || 0;
      }
      function validatePetRequestAmount(project, pet, requestedAmount) {
        requestedAmount = Number(requestedAmount) || 0;
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
        var cost = Number(vm.form && vm.form.cost) || 0;
        if (cost <= 0) { noticeError("A positive Budget Line amount is required."); return false; }
        var available = (Number(vm.selectedPet && vm.selectedPet.requestedAmount) || 0) - petBudgetLineTotal(vm.selectedPet, vm.form && vm.form.budgetLineId);
        if (cost > available) {
          noticeError("Budget Line amount exceeds the available balance for PET Reference " + (vm.selectedPet && vm.selectedPet.code || "") + ". Available balance: " + vm.money(Math.max(available, 0)) + "; entered amount: " + vm.money(cost) + ".");
          return false;
        }
        return true;
      }
      vm.updateView = function (keepPage) {
        var query = vm.search.toLowerCase();
        var currentEmail = (vm.session && vm.session.email || "").toLowerCase();
        var currentName = (vm.session && vm.session.displayName || "").toLowerCase();
        var filtered = vm.projects.filter(function (p) {
          var pets = p.pets || [];
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
            (!vm.statusFilter || p.status === vm.statusFilter) &&
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
          p.pets.forEach(function (pet) {
            if (pet.status === "Pending Review" && canReview && vm.isReviewerForPet(p, pet)) result.push({ project: p, pet: pet, stage: "review", action: "Review" });
            if (pet.status === "Pending Approval" && canApprove && vm.isApproverForPet(p, pet)) result.push({ project: p, pet: pet, stage: "approve", action: "Approve" });
          });
        });
        return result;
      }
      vm.updateApprovalView = function (keepPage) {
        var query = (vm.approvalSearch || "").toLowerCase();
        var filtered = (vm.approvalItems || []).filter(function (item) {
          return !query || [item.project.projectCode, item.project.jiraKey, item.project.projectName, item.project.projectType, item.pet.code, item.pet.status, item.project.budgetSource, item.project.requestorEmail, item.project.requestorName, item.pet.reviewerEmail, item.pet.approverEmail].join(" ").toLowerCase().indexOf(query) >= 0;
        });
        vm.approvalFilteredCount = filtered.length;
        vm.approvalPageCount = Math.max(1, Math.ceil(filtered.length / vm.approvalPageSize));
        if (!keepPage || vm.approvalPage > vm.approvalPageCount) vm.approvalPage = 1;
        var start = (vm.approvalPage - 1) * vm.approvalPageSize;
        vm.visibleApprovalItems = filtered.slice(start, start + vm.approvalPageSize);
      };
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
      vm.toggleProject = function (project) {
        if (project.expanded) { project.expanded = false; redraw(); return; }
        if (project.petsLoaded || vm.demo) { project.expanded = true; redraw(); return; }
        loadProjectPets(project, true);
      };
      function loadProjectPets(project, expandRegardless) {
        project.loading = true;
        return $http.get("api/portfolio/projects/" + project.projectId).then(function (response) {
          var data = response.data;
          project.pets = data.pets || [];
          project.pets.forEach(function (pet) {
            pet.spendItems = (data.spendItems || []).filter(function (item) { return item.petId === pet.petId; });
            pet.budgetLines = (data.budgetLines || []).filter(function (line) { return line.petId === pet.petId; });
            pet.budgetLines.forEach(function (line) { line.invoices = (data.invoices || []).filter(function (invoice) { return invoice.budgetLineId === line.budgetLineId; }); });
          });
          project.petsLoaded = true;
          project.loading = false;
          project.expanded = expandRegardless || project.pets.length > 0;
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
        vm.selectedProject = project;
        vm.selectedPet = pet;
        vm.uploadFile = null;
        vm.uploadPreview = [];
        vm.form = angular.copy(pet || {
            projectId: project.projectId,
            code: "PET-2026-" + String(Date.now()).slice(-4),
            currency: "AED",
            requestedAmount: 0,
          });
        if (pet) {
          vm.form.petId = vm.form.petId || pet.petId || pet.PetId;
          vm.form.projectId = vm.form.projectId || project.projectId;
          vm.form.code = vm.form.code || pet.code || pet.Code;
          vm.form.currency = vm.form.currency || pet.currency || pet.Currency || "AED";
          vm.form.requestedAmount = Number(vm.form.requestedAmount || pet.requestedAmount || pet.RequestedAmount) || 0;
          vm.form.status = vm.form.status || pet.status || pet.Status;
          if (vm.form.status === "Sent Back") vm.form.comments = "";
          if (sameStatus(vm.form.status, "Approved")) vm.form.vendorName = existingPetVendor(pet);
        }
        vm.modal = {
          type: "pet",
          kicker: "PET REQUEST",
          title: pet ? "Edit " + vm.form.code : "Create PET for " + vm.projectDisplayId(project),
          submit: pet && sameStatus(vm.form.status, "Approved") ? "Save vendor name" : pet && vm.form.status === "Sent Back" ? "Resubmit for approval" : pet ? "Save PET" : "Submit for review",
        };
        redraw();
      };
      vm.petVendorOnly = function () { return vm.selectedPet && sameStatus(vm.form && vm.form.status || vm.selectedPet.status, "Approved"); };
      vm.openSpend = function (pet) {
        vm.selectedPet = pet;
        vm.selectedProject = vm.projects.filter(function (project) { return project.pets.indexOf(pet) >= 0; })[0];
        vm.selectedPet.spendItems = vm.selectedPet.spendItems || [];
        vm.spendEditable = vm.can("request") && (pet.status === "Pending Review" || pet.status === "Sent Back" || (pet.status === "Pending Approval" && vm.selectedProject && vm.selectedProject.skipReview));
        vm.spendFormVisible = false;
        vm.form = { petId: pet.petId, units: 1, currency: "AED", contingencyPercent: 0 };
        vm.modal = { type: "spend", kicker: "PET COST DETAIL", title: "PET line items · " + pet.code, submit: "Save PET line item" };
        redraw();
      };
      vm.addSpend = function () {
        vm.form = { petId: vm.selectedPet.petId, units: 1, currency: "AED", contingencyPercent: 0 };
        vm.spendFormVisible = true;
        redraw();
      };
      vm.editSpend = function (item) {
        vm.form = angular.copy(item);
        vm.spendFormVisible = true;
        redraw();
      };
      vm.openDecision = function (pet, stage) {
        vm.selectedProject = vm.projects.filter(function (p) {
          return p.pets.indexOf(pet) >= 0;
        })[0];
        vm.form = angular.copy(pet);
        vm.form.decision = "Approve";
        vm.form.comments = "";
        vm.form.budgetSourceId = vm.selectedProject && vm.selectedProject.budgetSourceId;
        vm.modal = {
          type: "decision",
          stage: stage,
          kicker:
            stage === "review" ? "REVIEWER DECISION" : "APPROVER DECISION",
          title: stage === "review" ? "Review PET" : "Approve PET",
          submit: "Record decision",
        };
        redraw();
      };
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
      vm.onBudgetLinePetChange = function () {
        var pet = projectPetById(vm.selectedProject, vm.form && vm.form.petId);
        if (!pet) { vm.selectedPet = null; if (vm.form) vm.form.petReference = null; return; }
        vm.selectedPet = pet;
        vm.form.petReference = pet.code;
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
          submit: "Upload files",
          template: templates[kind],
          help:
            kind === "attachment"
              ? "PDF, spreadsheet and image files up to 50 MB."
              : "Use the supplied CSV columns. Invalid rows are rejected with a row-level reason.",
        };
        vm.uploadFile = null;
        vm.uploadPreview = [];
        vm.form = { item: item };
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
        redraw();
      };
      function runBulkImport(kind, parentId, onDone) {
        if (!vm.uploadFile) { noticeError("Choose a CSV file first."); return; }
        var reader = new FileReader();
        reader.onload = function (event) {
          $timeout(function () {
            $http.post("api/portfolio/bulk/" + kind + "/" + parentId, event.target.result, { headers: { "Content-Type": "text/plain" } }).then(function (response) {
              notice((response.data.imported || 0) + " row(s) imported.");
              vm.uploadFile = null;
              vm.close();
              onDone();
              loadDashboard();
            }, function (response) {
              noticeError(responseMessage(response, "Import failed."));
            });
          });
        };
        reader.readAsText(vm.uploadFile);
      }
      function savePreviewItems(petId) {
        if ((vm.uploadPreview || []).length && !petId) return $q.reject({ data: { message: "PET was saved, but the PET id was not returned." } });
        var chain = $q.when();
        (vm.uploadPreview || []).forEach(function (row) {
          chain = chain.then(function () {
            var payload = angular.extend({}, row, { petId: petId });
            payload.foreignAmount = Number(payload.foreignAmount) || (Number(payload.units) || 0) * (Number(payload.unitPrice) || 0);
            payload.aedAmount = Number(payload.aedAmount) || payload.foreignAmount;
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
              requestedAmount: Number(vm.form.requestedAmount) || 0,
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
          if (vm.uploadFile) {
            if (!vm.uploadPreview.length) { noticeError("No PET rows were found in the uploaded CSV."); return; }
            vm.recalculateUploadPreview();
          }
          if (vm.form.status === "Sent Back" && !String(vm.form.comments || "").trim()) { noticeError("Requester comments / amendment notes are required before resubmitting."); return; }
          if (!validatePetRequestAmount(vm.selectedProject, vm.selectedPet, vm.form.requestedAmount)) return;
          var petPayload = {
            petId: vm.form.petId || null,
            projectId: vm.selectedProject.projectId,
            code: vm.form.code,
            requestedAmount: vm.form.requestedAmount,
            currency: vm.form.currency,
            vendorName: vm.form.vendorName,
            comments: vm.form.comments,
          };
          $http.post("api/portfolio/pets", petPayload).then(function (response) {
            var savedPetId = petPayload.petId || response.data && (response.data.petId || response.data.PetId);
            savePreviewItems(savedPetId).then(function () {
              notice(vm.form.status === "Sent Back" ? "PET resubmitted for approval" : petPayload.petId ? "PET updated" : "PET submitted for review");
              vm.close();
              refreshProjectPets(petPayload.projectId, true);
              loadDashboard();
            }, function (itemResponse) {
              noticeError(responseMessage(itemResponse, "Unable to save the PET line items."));
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
          if (!validatePetRequestAmount(vm.selectedProject, vm.selectedPet, vm.form.requestedAmount)) return;
          var wasSentBack = vm.selectedPet && vm.selectedPet.status === "Sent Back";
          if (vm.selectedPet) angular.extend(vm.selectedPet, vm.form);
          else {
            vm.form.petId = Date.now();
            vm.form.status = vm.selectedProject.skipReview ? "Pending Approval" : "Pending Review";
            vm.form.createdUtc = new Date();
            vm.form.spendItems = [];
            vm.form.budgetLines = [];
            vm.selectedProject.pets.push(vm.form);
            vm.metrics.petsOnTrack++;
          }
          if (wasSentBack) vm.selectedPet.status = "Pending Approval";
          vm.selectedProject.status = wasSentBack ? "Pending Approval" : vm.selectedProject.skipReview ? "Pending Approval" : "Pending Review";
          prepareProjects();
          vm.updateView();
          notice(wasSentBack ? "PET resubmitted for approval" : vm.selectedPet ? "PET updated" : vm.selectedProject.skipReview ? "PET sent directly to the Accountable Executive" : "PET submitted to the Accountable Executive Lead");
        }
        if (type === "spend" && !vm.demo) {
          var spendPayload = angular.extend({}, vm.form, { petId: vm.selectedPet.petId });
          spendPayload.foreignAmount = Number(spendPayload.foreignAmount) || (Number(spendPayload.units) || 0) * (Number(spendPayload.unitPrice) || 0);
          spendPayload.aedAmount = Number(spendPayload.aedAmount) || spendPayload.foreignAmount;
          if (!validatePetRequestAmount(vm.selectedProject, vm.selectedPet, petFinalAedWithSpend(vm.selectedPet, spendPayload))) return;
          var isNewSpend = !spendPayload.spendItemId;
          $http.post("api/portfolio/spend-items", spendPayload).then(function (response) {
            var saved = response.data || {};
            spendPayload.spendItemId = saved.spendItemId || spendPayload.spendItemId;
            spendPayload.foreignAmount = spendPayload.units * spendPayload.unitPrice;
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
          var oldSpend = vm.form.spendItemId && vm.selectedPet.spendItems.filter(function (item) { return item.spendItemId === vm.form.spendItemId; })[0];
          vm.form.foreignAmount = vm.form.units * vm.form.unitPrice;
          vm.form.aedAmount = vm.form.aedAmount || vm.form.foreignAmount;
          if (!validatePetRequestAmount(vm.selectedProject, vm.selectedPet, petFinalAedWithSpend(vm.selectedPet, vm.form))) return;
          if (oldSpend) angular.extend(oldSpend, vm.form);
          else { vm.form.spendItemId = Date.now(); vm.selectedPet.spendItems.push(vm.form); }
          vm.selectedPet.requestedAmount = vm.petFinalAed(vm.selectedPet);
          prepareProjects();
          vm.updateView();
          notice("PET line item saved");
        }
        if (type === "decision" && !vm.demo) {
          var decisionRoute = vm.modal.stage === "review" ? "review" : "approve";
          if (!vm.form.decision) { noticeError("Select a decision before recording this request."); return; }
          if ((vm.form.decision === "SendBack" || vm.form.decision === "RejectCancel") && !String(vm.form.comments || "").trim()) { noticeError("Comments / reason is required for this decision."); return; }
          if (vm.modal.stage === "approve" && vm.form.decision === "Approve" && !vm.form.budgetSourceId) { noticeError("Select a CapEx source before approval."); return; }
          var decisionPayload = { comments: vm.form.comments, decision: vm.form.decision, approve: vm.form.decision === "Approve" };
          if (vm.modal.stage === "approve" && vm.form.decision === "Approve") decisionPayload.budgetSourceId = vm.form.budgetSourceId;
          $http.post("api/portfolio/pets/" + vm.form.petId + "/" + decisionRoute, decisionPayload).then(function () {
            notice("Decision recorded");
            vm.close();
            refreshProjectPets(vm.selectedProject.projectId, true);
            loadDashboard();
          }, function (response) {
            noticeError(responseMessage(response, "Unable to record this decision."));
          });
          return;
        }
        if (type === "decision") {
          if (!vm.form.decision) { noticeError("Select a decision before recording this request."); return; }
          if ((vm.form.decision === "SendBack" || vm.form.decision === "RejectCancel") && !String(vm.form.comments || "").trim()) { noticeError("Comments / reason is required for this decision."); return; }
          if (vm.modal.stage === "approve" && vm.form.decision === "Approve" && !vm.form.budgetSourceId) { noticeError("Select a CapEx source before approval."); return; }
          var target = vm.selectedProject.pets.filter(function (p) {
            return p.petId === vm.form.petId;
          })[0];
          target.status = vm.form.decision === "SendBack" ? "Sent Back" : vm.form.decision === "RejectCancel" ? "Rejected" : vm.modal.stage === "review" ? "Pending Approval" : "Approved";
          vm.selectedProject.status = target.status;
          if (target.status === "Approved") {
            if (vm.form.budgetSourceId) {
              var selectedBudget = vm.selectedBudgetSource();
              vm.selectedProject.budgetSourceId = vm.form.budgetSourceId;
              vm.selectedProject.budgetType = "CAPEX";
              if (selectedBudget) vm.selectedProject.budgetSource = selectedBudget.externalId;
            }
            vm.metrics.petsApproved++;
            vm.metrics.petsOnTrack--;
            vm.selectedProject.availableBudget -= target.requestedAmount;
          } else if (target.status === "Rejected") {
            vm.metrics.petsRejected++;
            vm.metrics.petsOnTrack--;
          }
          if (vm.modal.stage === "review") { target.reviewerEmail = vm.session.email; target.reviewedUtc = new Date(); }
          if (vm.modal.stage === "approve") target.approverEmail = vm.session.email;
          prepareProjects();
          vm.updateView();
          notice("Decision recorded");
        }
        if (type === "budgetLine" && !vm.demo) {
          vm.onBudgetLinePetChange();
          if (!vm.selectedPet) { noticeError("Select a PET reference before saving the budget line."); return; }
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
          vm.onBudgetLinePetChange();
          if (!vm.selectedPet) { noticeError("Select a PET reference before saving the budget line."); return; }
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
          var invoicePayload = angular.extend({}, vm.form, { budgetLineId: vm.selectedLine.budgetLineId });
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
          angular.extend(vm.selectedBudget, vm.form);
          notice("Budget source updated");
        }
        if (type === "upload" && vm.modal.kind !== "attachment" && vm.modal.kind !== "sources" && !vm.demo) {
          var item = vm.form.item;
          var kind = vm.modal.kind;
          var parentId = kind === "pet" ? item.projectId : kind === "budget" ? item.petId : kind === "invoice" ? item.budgetLineId : null;
          if (!parentId) { noticeError("Unable to determine where to import these rows."); return; }
          runBulkImport(kind, parentId, function () {
            if (kind === "pet") refreshProjectPets(parentId, true);
            else if (vm.selectedProject) refreshProjectPets(vm.selectedProject.projectId, true);
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
        $http.get("api/portfolio/dashboard").then(function (response) {
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
        }, redraw);
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
        if (!vm.hasRole("Admin") || vm.demo) return;
        $http.get("api/portfolio/roles").then(function (response) {
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
      prepareProjects();
      vm.updateView();
      redraw();
    });
})();
